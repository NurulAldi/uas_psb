-- =====================================================
-- LOCATION-BASED RENTAL FEATURE (20KM RADIUS)
-- Database Migration for RentLens
-- =====================================================
-- Purpose: Enable location-based product filtering
--          to show only products within 20km radius
-- =====================================================

-- 1. Add location columns to profiles table
ALTER TABLE profiles 
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS address TEXT,
  ADD COLUMN IF NOT EXISTS city TEXT,
  ADD COLUMN IF NOT EXISTS location_updated_at TIMESTAMPTZ DEFAULT NOW();

-- Add comment for documentation
COMMENT ON COLUMN profiles.latitude IS 'User location latitude for distance calculation';
COMMENT ON COLUMN profiles.longitude IS 'User location longitude for distance calculation';
COMMENT ON COLUMN profiles.address IS 'Full address from geocoding';
COMMENT ON COLUMN profiles.city IS 'City name for display purposes';
COMMENT ON COLUMN profiles.location_updated_at IS 'Last time user updated their location';

-- 2. Create index for faster geospatial queries
-- Using btree index for latitude and longitude separately
CREATE INDEX IF NOT EXISTS idx_profiles_latitude ON profiles(latitude) WHERE latitude IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_longitude ON profiles(longitude) WHERE longitude IS NOT NULL;

-- 3. Create function to calculate distance using Haversine formula
-- Returns distance in kilometers between two points
CREATE OR REPLACE FUNCTION calculate_distance_km(
  lat1 DOUBLE PRECISION,
  lon1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION,
  lon2 DOUBLE PRECISION
)
RETURNS DOUBLE PRECISION AS $$
DECLARE
  earth_radius DOUBLE PRECISION := 6371; -- Earth radius in kilometers
  dlat DOUBLE PRECISION;
  dlon DOUBLE PRECISION;
  a DOUBLE PRECISION;
  c DOUBLE PRECISION;
BEGIN
  -- Handle NULL values
  IF lat1 IS NULL OR lon1 IS NULL OR lat2 IS NULL OR lon2 IS NULL THEN
    RETURN NULL;
  END IF;

  -- Calculate differences in radians
  dlat := radians(lat2 - lat1);
  dlon := radians(lon2 - lon1);
  
  -- Haversine formula
  a := sin(dlat/2) * sin(dlat/2) + 
       cos(radians(lat1)) * cos(radians(lat2)) * 
       sin(dlon/2) * sin(dlon/2);
  c := 2 * atan2(sqrt(a), sqrt(1-a));
  
  RETURN earth_radius * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_distance_km IS 'Calculate distance in km between two GPS coordinates using Haversine formula';

-- 4. Create view: products with owner location information
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
  prof.latitude AS owner_lat,
  prof.longitude AS owner_lon,
  prof.address AS owner_address,
  prof.city AS owner_city,
  prof.full_name AS owner_name,
  prof.avatar_url AS owner_avatar
FROM products p
JOIN profiles prof ON p.owner_id = prof.id
WHERE prof.latitude IS NOT NULL 
  AND prof.longitude IS NOT NULL
  AND p.is_available = true;

COMMENT ON VIEW products_with_location IS 'Products with complete owner location information for distance calculation';

-- 5. Create function to get nearby products within specified radius
CREATE OR REPLACE FUNCTION get_nearby_products(
  user_lat DOUBLE PRECISION,
  user_lon DOUBLE PRECISION,
  radius_km DOUBLE PRECISION DEFAULT 20.0,
  product_category TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  category TEXT,
  price_per_day DECIMAL,
  image_url TEXT,
  is_available BOOLEAN,
  owner_id UUID,
  owner_name TEXT,
  owner_city TEXT,
  owner_avatar TEXT,
  distance_km DOUBLE PRECISION,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pwl.id,
    pwl.name,
    pwl.description,
    pwl.category,
    pwl.price_per_day,
    pwl.image_url,
    pwl.is_available,
    pwl.owner_id,
    pwl.owner_name,
    pwl.owner_city,
    pwl.owner_avatar,
    calculate_distance_km(user_lat, user_lon, pwl.owner_lat, pwl.owner_lon) AS distance_km,
    pwl.created_at
  FROM products_with_location pwl
  WHERE calculate_distance_km(user_lat, user_lon, pwl.owner_lat, pwl.owner_lon) <= radius_km
    AND (product_category IS NULL OR pwl.category::TEXT = product_category)
  ORDER BY distance_km ASC, pwl.created_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_nearby_products IS 'Get available products within specified radius (default 20km) sorted by distance';

-- 6. Create function to get product distance for a specific user
CREATE OR REPLACE FUNCTION get_product_distance(
  product_id UUID,
  user_lat DOUBLE PRECISION,
  user_lon DOUBLE PRECISION
)
RETURNS DOUBLE PRECISION AS $$
DECLARE
  owner_lat DOUBLE PRECISION;
  owner_lon DOUBLE PRECISION;
BEGIN
  -- Get owner location
  SELECT latitude, longitude INTO owner_lat, owner_lon
  FROM profiles
  WHERE id = (SELECT owner_id FROM products WHERE id = product_id);
  
  -- Calculate and return distance
  RETURN calculate_distance_km(user_lat, user_lon, owner_lat, owner_lon);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_product_distance IS 'Calculate distance from user to product owner location';

-- 7. Update RLS policies to allow location updates
-- Users can update their own location
CREATE POLICY "Users can update own location" ON profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id AND
    -- Ensure critical fields are not changed
    role IS NOT DISTINCT FROM (SELECT role FROM profiles WHERE id = auth.uid()) AND
    is_banned IS NOT DISTINCT FROM (SELECT is_banned FROM profiles WHERE id = auth.uid())
  );

-- 8. Create trigger to auto-update location_updated_at
CREATE OR REPLACE FUNCTION update_location_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  IF (NEW.latitude IS DISTINCT FROM OLD.latitude) OR 
     (NEW.longitude IS DISTINCT FROM OLD.longitude) THEN
    NEW.location_updated_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_location_timestamp
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_location_timestamp();

COMMENT ON TRIGGER trigger_update_location_timestamp ON profiles IS 'Auto-update location_updated_at when latitude or longitude changes';

-- 9. Add validation constraint (latitude: -90 to 90, longitude: -180 to 180)
ALTER TABLE profiles
  ADD CONSTRAINT check_latitude_range 
    CHECK (latitude IS NULL OR (latitude >= -90 AND latitude <= 90));

ALTER TABLE profiles
  ADD CONSTRAINT check_longitude_range 
    CHECK (longitude IS NULL OR (longitude >= -180 AND longitude <= 180));

-- =====================================================
-- TESTING QUERIES (Comment out in production)
-- =====================================================

-- Test 1: Calculate distance between two points
-- SELECT calculate_distance_km(-6.9175, 107.6191, -6.2088, 106.8456) AS jakarta_bandung_km;
-- Expected: ~120 km

-- Test 2: Get nearby products (example coordinates: Bandung city center)
-- SELECT * FROM get_nearby_products(-6.9175, 107.6191, 20.0);

-- Test 3: Get distance to specific product
-- SELECT get_product_distance('product-uuid-here', -6.9175, 107.6191);

-- =====================================================
-- ROLLBACK SCRIPT (if needed)
-- =====================================================
/*
-- Drop triggers
DROP TRIGGER IF EXISTS trigger_update_location_timestamp ON profiles;
DROP FUNCTION IF EXISTS update_location_timestamp();

-- Drop functions
DROP FUNCTION IF EXISTS get_product_distance(UUID, DOUBLE PRECISION, DOUBLE PRECISION);
DROP FUNCTION IF EXISTS get_nearby_products(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT);
DROP FUNCTION IF EXISTS calculate_distance_km(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);

-- Drop view
DROP VIEW IF EXISTS products_with_location;

-- Drop indexes
DROP INDEX IF EXISTS idx_profiles_longitude;
DROP INDEX IF EXISTS idx_profiles_latitude;

-- Drop constraints
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS check_longitude_range;
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS check_latitude_range;

-- Drop columns
ALTER TABLE profiles 
  DROP COLUMN IF EXISTS location_updated_at,
  DROP COLUMN IF EXISTS city,
  DROP COLUMN IF EXISTS address,
  DROP COLUMN IF EXISTS longitude,
  DROP COLUMN IF EXISTS latitude;
*/

-- =====================================================
-- END OF MIGRATION
-- =====================================================
