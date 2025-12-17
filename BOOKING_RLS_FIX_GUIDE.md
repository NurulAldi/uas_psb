# BOOKING RLS POLICY FIX - Row Level Security Violation

## 🚨 PROBLEM IDENTIFIED

Booking creation fails with:
```
PostgrestException(message: new row violates row-level security policy for table "bookings", code: 42501, details: Unauthorized, hint: null)
```

## 🔍 ROOT CAUSE ANALYSIS

**Backend Engineer Perspective:**

1. **RLS Policy Issue**: The `bookings` table has RLS policies that check `auth.uid() = user_id`
2. **Authentication Mismatch**: The app uses custom authentication with a `users` table, not Supabase Auth
3. **Session Context Missing**: Booking creation doesn't call `set_user_context()` before insertion
4. **Policy Logic**: `auth.uid()` returns null (no Supabase Auth user), so policy fails

## ✅ SOLUTION

### Step 1: Update Flutter Code (Already Done)

The booking repository now calls `set_user_context()` before creating bookings:

```dart
// Set user context for RLS policies
await _supabase.rpc('set_user_context', params: {'user_id': userId});
```

### Step 2: Update Database RLS Policies

**Run this SQL in Supabase SQL Editor:**

```sql
-- Drop the old policy that uses auth.uid()
DROP POLICY IF EXISTS "Users can create bookings" ON bookings;

-- Create new policy that uses session context (compatible with custom auth)
CREATE POLICY "Users can create bookings"
    ON bookings
    FOR INSERT
    WITH CHECK (
        user_id = (current_setting('app.current_user_id', true)::UUID)
        AND user_id IS NOT NULL
    );

-- Also update other booking policies to be consistent
DROP POLICY IF EXISTS "Users and owners can update bookings" ON bookings;
CREATE POLICY "Users and owners can update bookings"
    ON bookings
    FOR UPDATE
    USING (
        user_id = (current_setting('app.current_user_id', true)::UUID)
        OR product_id IN (
            SELECT id FROM products
            WHERE owner_id = (current_setting('app.current_user_id', true)::UUID)
        )
    )
    WITH CHECK (
        user_id = (current_setting('app.current_user_id', true)::UUID)
        OR product_id IN (
            SELECT id FROM products
            WHERE owner_id = (current_setting('app.current_user_id', true)::UUID)
        )
    );

DROP POLICY IF EXISTS "Users can delete their own bookings" ON bookings;
CREATE POLICY "Users can delete their own bookings"
    ON bookings
    FOR DELETE
    USING (user_id = (current_setting('app.current_user_id', true)::UUID));
```

### Step 3: Verification

After running the SQL, try creating a booking again. It should work without RLS violations.

## 📋 TECHNICAL DETAILS

**Before (Broken):**
- Policy: `auth.uid() = user_id` (Supabase Auth)
- Context: No session variable set
- Result: `auth.uid()` = null → Policy fails

**After (Fixed):**
- Policy: `current_setting('app.current_user_id') = user_id` (Session context)
- Context: `set_user_context(userId)` called before insert
- Result: Session variable matches user_id → Policy passes

**Architecture Pattern:**
- Custom authentication with `users` table
- Session-based RLS using `set_user_context()`
- Consistent with other tables (products, etc.)

## ✅ VERIFICATION CHECKLIST

- [ ] SQL script executed in Supabase SQL Editor
- [ ] Booking creation works without RLS errors
- [ ] Booking appears in user's booking list
- [ ] Product owner can see the booking

---

**File**: `supabase_booking_rls_fix.sql` (created)
**Status**: Ready to execute in Supabase SQL Editor