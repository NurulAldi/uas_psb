# Quick Migration Checklist

## ✅ Pre-Flight Check

Before running the SQL scripts:

1. **Backup your Supabase project**
   - Go to Supabase Dashboard → Settings → Database
   - Click "Database Backups" and create a manual backup
   
2. **Check extensions availability**
   ```sql
   -- Run in Supabase SQL Editor
   SELECT * FROM pg_available_extensions 
   WHERE name IN ('postgis', 'pgcrypto', 'pg_trgm');
   ```

## 🚀 Migration Steps

### Step 1: Enable PostGIS Extension

```sql
-- In Supabase SQL Editor, run:
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

**Alternative (UI)**:
- Dashboard → Database → Extensions
- Search for "postgis" → Click "Enable"
- Search for "pgcrypto" → Click "Enable"
- Search for "pg_trgm" → Click "Enable"

### Step 2: Run Hybrid Auth Migration

Copy and paste the **entire** contents of `supabase_hybrid_auth_migration.sql` into the Supabase SQL Editor and click "Run".

**Expected output**:
- `CREATE EXTENSION` (3 times)
- `CREATE TABLE`
- `CREATE INDEX` (multiple)
- `ALTER TABLE`
- `CREATE POLICY` (4 times)
- `CREATE FUNCTION` (multiple)
- `UPDATE` (1 row affected if profiles exist)

**If errors occur**: See troubleshooting section below.

### Step 3: Run Location-First Products Migration

Copy and paste the **entire** contents of `supabase_location_first_products.sql` into the Supabase SQL Editor and click "Run".

**Expected output**:
- `CREATE EXTENSION`
- `DROP FUNCTION` (if exists)
- `CREATE FUNCTION`
- `CREATE INDEX` (multiple)
- `CREATE TRIGGER`

### Step 4: Verify Installation

Run these verification queries:

```sql
-- 1. Check custom_users table exists
SELECT COUNT(*) FROM custom_users;
-- Expected: 0 (empty table)

-- 2. Check profiles have auth_type
SELECT auth_type, COUNT(*) 
FROM profiles 
GROUP BY auth_type;
-- Expected: Shows 'supabase_auth' with count of existing users

-- 3. Check nearby products function
SELECT * FROM get_nearby_products(-6.9175, 107.6191, 20.0)
LIMIT 5;
-- Expected: Returns products (or empty if no products with location)

-- 4. Check indexes
SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE indexname LIKE '%location%';
-- Expected: Shows geography and composite indexes

-- 5. Check extensions
SELECT * FROM pg_extension 
WHERE extname IN ('postgis', 'pgcrypto', 'pg_trgm');
-- Expected: All 3 extensions listed
```

## ⚠️ Troubleshooting

### Error: "extension does not exist"

**Problem**: PostGIS not available in your Supabase plan.

**Solution**: The migration includes fallback indexes. The error is safe to ignore for `CREATE EXTENSION`, but verify fallback indexes created:

```sql
SELECT indexname FROM pg_indexes 
WHERE tablename IN ('profiles', 'custom_users')
AND indexname LIKE '%lat%';
-- Should show: idx_profiles_lat_lon_composite, etc.
```

### Error: "column does not exist"

**Problem**: You're running on a fresh Supabase project without the base schema.

**Solution**: First run your base migration (the one that creates `profiles`, `products`, etc.), then run these migrations.

### Error: "function calculate_distance_km does not exist"

**Problem**: The distance calculation function hasn't been created yet.

**Solution**: Add this to your migration or run separately:

```sql
CREATE OR REPLACE FUNCTION calculate_distance_km(
  lat1 DOUBLE PRECISION,
  lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION,
  lon2 DOUBLE PRECISION
)
RETURNS DOUBLE PRECISION AS $$
DECLARE
  earth_radius_km CONSTANT DOUBLE PRECISION := 6371.0;
  dlat DOUBLE PRECISION;
  dlon DOUBLE PRECISION;
  a DOUBLE PRECISION;
  c DOUBLE PRECISION;
BEGIN
  -- Haversine formula
  dlat := radians(lat2 - lat1);
  dlon := radians(lon2 - lon1);
  a := sin(dlat/2) * sin(dlat/2) + 
       cos(radians(lat1)) * cos(radians(lat2)) * 
       sin(dlon/2) * sin(dlon/2);
  c := 2 * atan2(sqrt(a), sqrt(1-a));
  
  RETURN earth_radius_km * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;
```

### Error: "view products_with_location does not exist"

**Problem**: Base view not created.

**Solution**: Create the view:

```sql
CREATE OR REPLACE VIEW products_with_location AS
SELECT 
  p.*,
  prof.full_name AS owner_name,
  prof.city AS owner_city,
  prof.avatar_url AS owner_avatar,
  prof.latitude AS owner_lat,
  prof.longitude AS owner_lon
FROM products p
INNER JOIN profiles prof ON p.owner_id = prof.id
WHERE p.is_available = true
  AND prof.latitude IS NOT NULL
  AND prof.longitude IS NOT NULL;
```

## 🧪 Testing Your Migration

### Test 1: Custom User Registration

```sql
-- Insert a test user
INSERT INTO custom_users (username, password_hash, full_name, email)
VALUES (
  'testuser',
  crypt('Password123!', gen_salt('bf', 12)),
  'Test User',
  'test@example.com'
)
RETURNING id, username, full_name;

-- Cleanup
DELETE FROM custom_users WHERE username = 'testuser';
```

### Test 2: Login Function

```sql
-- Test getting user by username
SELECT id, username, is_banned, login_attempts
FROM get_custom_user_by_username('testuser');
```

### Test 3: Nearby Products with Filters

```sql
-- Test all parameters
SELECT name, category, distance_km, distance_text
FROM get_nearby_products(
  -6.9175,  -- Bandung latitude
  107.6191, -- Bandung longitude
  30.0,     -- 30km radius
  'canon',  -- Search text
  'DSLR'    -- Category filter
)
LIMIT 10;
```

### Test 4: Geography Column Auto-Update

```sql
-- Update a profile location
UPDATE profiles
SET latitude = -6.9175, longitude = 107.6191
WHERE id = (SELECT id FROM profiles LIMIT 1)
RETURNING id, latitude, longitude, location_point;

-- Verify geography column updated automatically
SELECT 
  latitude,
  longitude,
  ST_Y(location_point::geometry) as geo_lat,
  ST_X(location_point::geometry) as geo_lon
FROM profiles
WHERE location_point IS NOT NULL
LIMIT 1;
-- geo_lat should match latitude, geo_lon should match longitude
```

## 📊 Performance Verification

Run these to check query performance:

```sql
-- Check spatial index usage
EXPLAIN ANALYZE 
SELECT * FROM get_nearby_products(-6.9175, 107.6191, 20.0);
-- Look for "Index Scan using idx_profiles_location_geography"

-- Check index size
SELECT 
  schemaname,
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) as index_size
FROM pg_stat_user_indexes
WHERE indexrelname LIKE '%location%';
```

## 🔄 Rollback Plan

If something goes wrong:

```sql
-- Drop new objects (in reverse order)
DROP TRIGGER IF EXISTS trigger_update_custom_users_location_point ON custom_users;
DROP TRIGGER IF EXISTS trigger_update_profiles_location_point ON profiles;
DROP FUNCTION IF EXISTS update_custom_users_location_point();
DROP FUNCTION IF EXISTS update_profiles_location_point();
DROP FUNCTION IF EXISTS get_nearby_products(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS set_custom_user_session(UUID);
DROP FUNCTION IF EXISTS clear_custom_user_session();
DROP FUNCTION IF EXISTS get_custom_user_by_username(TEXT);
DROP FUNCTION IF EXISTS increment_login_attempts(TEXT);
DROP FUNCTION IF EXISTS update_custom_user_login(UUID);
DROP FUNCTION IF EXISTS is_custom_user_banned(UUID);
DROP FUNCTION IF EXISTS username_exists(TEXT);
DROP VIEW IF EXISTS all_users;
DROP TABLE IF EXISTS custom_users;
ALTER TABLE profiles DROP COLUMN IF EXISTS location_point;
ALTER TABLE profiles DROP COLUMN IF EXISTS auth_type;

-- Then restore from your backup
```

## ✅ Success Criteria

Your migration is successful if:

- [ ] All SQL scripts run without errors
- [ ] Extensions (postgis, pgcrypto, pg_trgm) are enabled
- [ ] `custom_users` table exists and is empty
- [ ] Existing `profiles` have `auth_type = 'supabase_auth'`
- [ ] `get_nearby_products()` function returns results
- [ ] Geography columns exist on `profiles` and `custom_users`
- [ ] Spatial indexes are created
- [ ] All verification queries run successfully

## 📞 Need Help?

If you encounter issues not covered here:

1. Check the [SUPABASE_SQL_COMPATIBILITY_GUIDE.md](SUPABASE_SQL_COMPATIBILITY_GUIDE.md) for detailed explanations
2. Verify your base schema matches the expected structure
3. Check Supabase logs: Dashboard → Logs → Database Logs
4. Ensure you're on a Supabase plan that supports the required extensions

---

**Last updated**: December 15, 2024  
**Compatible with**: Supabase PostgreSQL 15+  
**Required extensions**: postgis (recommended), pgcrypto, pg_trgm
