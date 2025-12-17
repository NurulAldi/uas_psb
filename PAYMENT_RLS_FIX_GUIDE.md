# PAYMENT RLS POLICY FIX - Row Level Security Violation

## 🚨 PROBLEM IDENTIFIED

Payment creation fails with:
```
PostgrestException(message: new row violates row-level security policy for table "payments", code: 42501, details: Unauthorized, hint: null)
```

## 🔍 ROOT CAUSE ANALYSIS (Backend Engineer Perspective)

**The Problem:**
- RLS policy on `payments` table: `auth.uid()` based authentication
- App uses custom authentication with `users` table
- `auth.uid()` returns `null` → Policy fails on INSERT/SELECT operations

**The Architecture:**
- Custom auth system with session variables via `set_user_context()`
- Other tables (products, bookings) use `current_setting('app.current_user_id')`
- Payments table was still using old `auth.uid()` approach

**Affected Operations:**
- ✅ CREATE: `createPayment()` - Fixed with `set_user_context()`
- ✅ SELECT: `getUserPayments()` - Fixed with `set_user_context()`
- ✅ UPDATE: Webhook updates work (system policy allows all updates)

## ✅ SOLUTION IMPLEMENTED

### Step 1: Flutter Code Fixes (✅ Done)

**Payment Creation:**
```dart
// Set user context for RLS policies
await _supabase.rpc('set_user_context', params: {'user_id': currentUserId});
```

**Payment Queries:**
```dart
// Set user context for SELECT operations
await _supabase.rpc('set_user_context', params: {'user_id': userId});
```

### Step 2: Database RLS Policy Fix

**Run this SQL in Supabase SQL Editor:**

```sql
-- Drop old policies
DROP POLICY IF EXISTS "Users can view own payments" ON payments;
DROP POLICY IF EXISTS "Users can create own payments" ON payments;
DROP POLICY IF EXISTS "Users can update own payments" ON payments;
DROP POLICY IF EXISTS "Owners can view payments for their products" ON payments;

-- New policies using session context
CREATE POLICY "Users can view own payments"
    ON payments FOR SELECT
    USING (
        booking_id IN (
            SELECT id FROM bookings
            WHERE user_id = (current_setting('app.current_user_id', true)::UUID)
        )
    );

CREATE POLICY "Owners can view payments for their products"
    ON payments FOR SELECT
    USING (
        booking_id IN (
            SELECT b.id FROM bookings b
            JOIN products p ON b.product_id = p.id
            WHERE p.owner_id = (current_setting('app.current_user_id', true)::UUID)
        )
    );

CREATE POLICY "Users can create own payments"
    ON payments FOR INSERT
    WITH CHECK (
        booking_id IN (
            SELECT id FROM bookings
            WHERE user_id = (current_setting('app.current_user_id', true)::UUID)
        )
    );

CREATE POLICY "Users can update own payments"
    ON payments FOR UPDATE
    USING (
        booking_id IN (
            SELECT id FROM bookings
            WHERE user_id = (current_setting('app.current_user_id', true)::UUID)
        )
    )
    WITH CHECK (
        booking_id IN (
            SELECT id FROM bookings
            WHERE user_id = (current_setting('app.current_user_id', true)::UUID)
        )
    );
```

### Step 3: Verification

After running the SQL, try creating a payment again. It should work without RLS errors.

## 📋 TECHNICAL DETAILS

**Before (Broken):**
- Policy: `booking_id IN (SELECT id FROM bookings WHERE user_id = auth.uid())`
- Context: No session variable set
- Result: `auth.uid()` = null → Policy fails

**After (Fixed):**
- Policy: `user_id = current_setting('app.current_user_id')`
- Context: `set_user_context(userId)` called before operations
- Result: Session variable matches user_id → Policy passes

**Security Model:**
- Users can view payments for bookings they created
- Product owners can view payments for their products
- Users can create/update payments for their bookings
- System can update payments (for webhooks)

## ✅ VERIFICATION CHECKLIST

- [ ] SQL script executed in Supabase SQL Editor
- [ ] Payment creation works without RLS errors
- [ ] Payment appears in user's payment history
- [ ] Product owner can see payment in their dashboard
- [ ] Midtrans webhooks can still update payment status

---

**Files Modified:**
- `lib/features/payment/data/repositories/payment_repository.dart` (added `set_user_context` calls)
- `supabase_payment_rls_fix.sql` (created)

**Status:** Ready to execute SQL and test payment creation