-- =====================================================
-- Enhanced Nearby Products Function for Location-First Discovery
-- Supabase-Compatible Version with PostGIS Support
-- Supports search, category filtering, and distance-based sorting
-- =====================================================
-- COMPATIBILITY: Tested on Supabase PostgreSQL 15+
-- EXTENSIONS REQUIRED: PostGIS (optional, for better performance)
-- =====================================================

-- =====================================================
-- STEP 1: ENABLE REQUIRED EXTENSIONS (Supabase-safe)
-- =====================================================
-- PostGIS is the recommended geospatial extension for Supabase
-- If PostGIS is not needed, the script falls back to standard B-tree indexes

CREATE EXTENSION IF NOT EXISTS postgis;

-- =====================================================
-- STEP 2: DROP EXISTING FUNCTION OVERLOADS
-- =====================================================
DROP FUNCTION IF EXISTS get_nearby_products(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION);
DROP FUNCTION IF EXISTS get_nearby_products(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT);
DROP FUNCTION IF EXISTS get_nearby_products(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID);
DROP FUNCTION IF EXISTS get_nearby_products(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, UUID);

-- Enhanced function with search and filter support
CREATE OR REPLACE FUNCTION get_nearby_products(
  user_lat DOUBLE PRECISION,
  user_lon DOUBLE PRECISION,
  radius_km DOUBLE PRECISION DEFAULT 20.0,
  search_text TEXT DEFAULT NULL,
  filter_category TEXT DEFAULT NULL,
  exclude_user_id UUID DEFAULT NULL
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
  owner_latitude DOUBLE PRECISION,
  owner_longitude DOUBLE PRECISION,
  distance_km DOUBLE PRECISION,
  distance_text TEXT,
  travel_time_minutes INTEGER,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pwl.id,
    pwl.name,
    pwl.description,
    pwl.category::TEXT,
    pwl.price_per_day,
    pwl.image_url,
    pwl.is_available,
    pwl.owner_id,
    pwl.owner_name,
    pwl.owner_city,
    pwl.owner_avatar,
    pwl.owner_lat AS owner_latitude,
    pwl.owner_lon AS owner_longitude,
    calculate_distance_km(user_lat, user_lon, pwl.owner_lat, pwl.owner_lon) AS distance_km,
    -- Format distance text
    CASE 
      WHEN calculate_distance_km(user_lat, user_lon, pwl.owner_lat, pwl.owner_lon) < 1 
        THEN CONCAT(ROUND(calculate_distance_km(user_lat, user_lon, pwl.owner_lat, pwl.owner_lon) * 1000)::TEXT, ' m')
      ELSE CONCAT(ROUND((calculate_distance_km(user_lat, user_lon, pwl.owner_lat, pwl.owner_lon))::NUMERIC, 1)::TEXT, ' km')
    END AS distance_text,
    -- Estimate travel time (assume 30 km/h average city speed)
    ROUND((calculate_distance_km(user_lat, user_lon, pwl.owner_lat, pwl.owner_lon) / 30.0) * 60)::INTEGER AS travel_time_minutes,
    pwl.created_at,
    pwl.updated_at
  FROM products_with_location pwl
  WHERE 
    -- Distance filter
    calculate_distance_km(user_lat, user_lon, pwl.owner_lat, pwl.owner_lon) <= radius_km
    -- Only available products
    AND pwl.is_available = true
    -- Category filter (optional)
    AND (filter_category IS NULL OR pwl.category::TEXT = filter_category)
    -- Exclude current user's products (optional)
    AND (exclude_user_id IS NULL OR pwl.owner_id != exclude_user_id)
    -- Search filter (optional) - search in name and description
    AND (
      search_text IS NULL 
      OR pwl.name ILIKE '%' || search_text || '%'
      OR pwl.description ILIKE '%' || search_text || '%'
    )
  ORDER BY 
    -- Primary: Sort by distance (closest first)
    calculate_distance_km(user_lat, user_lon, pwl.owner_lat, pwl.owner_lon) ASC,
    -- Secondary: Newest products first
    pwl.created_at DESC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_nearby_products IS 
'Enhanced location-aware product search with filters.
Returns available products within radius, sorted by distance.
Supports search text, category filter, and user exclusion.';

-- =====================================================
-- STEP 3: PERFORMANCE OPTIMIZATION - SUPABASE-COMPATIBLE INDEXES
-- =====================================================

-- Option A: PostGIS spatial index (RECOMMENDED for Supabase)
-- Uses geography type for accurate distance calculations
-- This index dramatically improves performance for radius queries

-- First, add a geography column if PostGIS is available
-- This will fail gracefully if PostGIS is not enabled
DO $$ 
BEGIN
  -- Add geography point column for PostGIS optimization
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'location_point'
  ) THEN
    ALTER TABLE profiles ADD COLUMN location_point geography(POINT, 4326);
  END IF;
  
  -- Populate geography column from lat/lon
  UPDATE profiles 
  SET location_point = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
  WHERE latitude IS NOT NULL 
    AND longitude IS NOT NULL 
    AND location_point IS NULL;
    
EXCEPTION 
  WHEN undefined_function THEN
    -- PostGIS not available, skip geography column
    RAISE NOTICE 'PostGIS not available, skipping geography column';
END $$;

-- Create spatial index on geography column (PostGIS)
-- This uses GIST index which is efficient for spatial queries
CREATE INDEX IF NOT EXISTS idx_profiles_location_geography
ON profiles USING gist(location_point)
WHERE location_point IS NOT NULL;

-- Option B: Fallback B-tree indexes on latitude/longitude
-- These work without PostGIS but are less efficient for radius queries
CREATE INDEX IF NOT EXISTS idx_profiles_latitude 
ON profiles(latitude)
WHERE latitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_longitude 
ON profiles(longitude)
WHERE longitude IS NOT NULL;

-- Composite index for bounding box queries (improves performance)
CREATE INDEX IF NOT EXISTS idx_profiles_lat_lon_composite
ON profiles(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Product availability composite index
CREATE INDEX IF NOT EXISTS idx_products_available_category 
ON products(is_available, category, created_at)
WHERE is_available = true;

-- Product owner index for joins
CREATE INDEX IF NOT EXISTS idx_products_owner_available
ON products(owner_id, is_available)
WHERE is_available = true;

-- Full-text search optimization for product names and descriptions
CREATE INDEX IF NOT EXISTS idx_products_name_trgm
ON products USING gin(name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_products_description_trgm
ON products USING gin(description gin_trgm_ops);

-- =====================================================
-- STEP 4: CREATE TRIGGER TO MAINTAIN GEOGRAPHY COLUMN
-- =====================================================
-- Auto-update geography point when lat/lon changes

CREATE OR REPLACE FUNCTION update_profiles_location_point()
RETURNS TRIGGER AS $$
BEGIN
  -- Only update if PostGIS is available
  BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
      NEW.location_point := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    ELSE
      NEW.location_point := NULL;
    END IF;
  EXCEPTION
    WHEN undefined_function THEN
      -- PostGIS not available, skip
      NULL;
  END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists (idempotent)
DROP TRIGGER IF EXISTS trigger_update_profiles_location_point ON profiles;

-- Create trigger
CREATE TRIGGER trigger_update_profiles_location_point
  BEFORE INSERT OR UPDATE OF latitude, longitude ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_profiles_location_point();

-- =====================================================
-- Test Queries (Uncomment to test)
-- =====================================================

-- Test 1: Basic nearby search (Bandung coordinates)
-- SELECT * FROM get_nearby_products(-6.9175, 107.6191, 20.0);

-- Test 2: Search with text filter
-- SELECT * FROM get_nearby_products(-6.9175, 107.6191, 20.0, 'canon');

-- Test 3: Search with category filter
-- SELECT * FROM get_nearby_products(-6.9175, 107.6191, 20.0, NULL, 'DSLR');

-- Test 4: Search with all filters
-- SELECT * FROM get_nearby_products(-6.9175, 107.6191, 30.0, 'sony', 'Mirrorless');

-- Test 5: Verify distance sorting
-- SELECT name, distance_km, distance_text, travel_time_minutes 
-- FROM get_nearby_products(-6.9175, 107.6191, 50.0)
-- LIMIT 10;

-- =====================================================
-- Utility: Check query performance
-- =====================================================

-- EXPLAIN ANALYZE SELECT * FROM get_nearby_products(-6.9175, 107.6191, 20.0);
