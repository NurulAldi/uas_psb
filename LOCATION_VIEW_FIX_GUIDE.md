# LOCATION VIEW FIX - Products Not Showing on Home Page

## 🚨 PROBLEM IDENTIFIED

Products are not displaying on the home page despite being successfully created. The issue is in the `products_with_location` view which is incorrectly joining with the `profiles` table instead of the `users` table.

### Root Cause
- The `products_with_location` view joins `products.owner_id` with `profiles.id`
- But `products.owner_id` actually references `users.id` (after the clean auth migration)
- This causes the join to fail, returning no products

## ✅ SOLUTION

### Step 1: Run the View Fix SQL

1. **Open Supabase Dashboard**
   - Go to your Supabase project dashboard
   - Click **SQL Editor** in the left sidebar

2. **Execute the Fix Script**
   - Copy and paste the following SQL into the SQL Editor:
   ```sql
   -- =====================================================
   -- FIX: Update products_with_location view to join with users table
   -- =====================================================
   -- Issue: The view was joining with profiles table, but products.owner_id
   --        now references users.id after the clean auth migration
   -- =====================================================

   -- Drop the old view
   DROP VIEW IF EXISTS products_with_location;

   -- Recreate the view with correct join to users table
   CREATE OR REPLACE VIEW products_with_location AS
   SELECT
     p.id,
     p.name,
     p.description,
     p.category,
     p.price_per_day,
     p.image_url,
     p.is_available,
     p.owner_id,
     p.created_at,
     p.updated_at,
     u.latitude AS owner_lat,
     u.longitude AS owner_lon,
     u.address AS owner_address,
     u.city AS owner_city,
     u.full_name AS owner_name,
     u.avatar_url AS owner_avatar
   FROM products p
   JOIN users u ON p.owner_id = u.id
   WHERE u.latitude IS NOT NULL
     AND u.longitude IS NOT NULL
     AND p.is_available = true
     AND u.is_banned = false;

   COMMENT ON VIEW products_with_location IS 'Products with complete owner location information for distance calculation - Fixed to join with users table';
   ```

3. **Run the SQL**
   - Click the **Run** button (or press Ctrl+Enter)
   - You should see "Success. No rows returned" or similar success message

### Step 2: Verify the Fix

Run this test query in the SQL Editor to verify the view is working:

```sql
-- Test the fixed view
SELECT
  COUNT(*) as total_products,
  COUNT(CASE WHEN owner_lat IS NOT NULL AND owner_lon IS NOT NULL THEN 1 END) as products_with_location
FROM products_with_location;

-- Check if products exist and have location data
SELECT
  p.id,
  p.name,
  p.owner_id,
  u.username,
  u.latitude,
  u.longitude,
  u.city
FROM products p
JOIN users u ON p.owner_id = u.id
WHERE p.is_available = true
  AND u.latitude IS NOT NULL
  AND u.longitude IS NOT NULL
  AND u.is_banned = false
LIMIT 5;
```

### Step 3: Test in Flutter App

1. **Update User Location** (if not already done):
   - Login to the app
   - Go to Profile/Edit Profile
   - Set your location (latitude/longitude)

2. **Create a Test Product** (if you haven't already):
   - Go to Add Product page
   - Create a product with your location

3. **Check Home Page**:
   - Go to Home page
   - Products should now appear if you're within 15km of the product location

## 🔍 DEBUGGING

If products still don't show up, check these:

### Check 1: User Location Set
```sql
SELECT id, username, latitude, longitude, city
FROM users
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
```

### Check 2: Products Exist
```sql
SELECT id, name, owner_id, is_available
FROM products
WHERE is_available = true;
```

### Check 3: View Data
```sql
SELECT * FROM products_with_location LIMIT 5;
```

### Check 4: Distance Calculation
Test the `get_nearby_products` function:
```sql
SELECT * FROM get_nearby_products(
  -6.2088, 106.8456,  -- Jakarta coordinates (adjust to your location)
  15.0,               -- 15km radius
  NULL                 -- any category
);
```

## 📋 SUMMARY

- **Problem**: `products_with_location` view joined with wrong table
- **Fix**: Updated view to join `products.owner_id` with `users.id`
- **Result**: Products should now appear on home page based on location proximity

## ✅ VERIFICATION CHECKLIST

- [ ] SQL fix executed successfully
- [ ] View returns products when queried
- [ ] User has location data set
- [ ] Products exist and are available
- [ ] App shows products on home page
- [ ] Distance filtering works (15km radius)

---

**File**: `supabase_location_view_fix.sql` (created)
**Status**: Ready to execute in Supabase SQL Editor