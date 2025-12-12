-- Fix for get_nearby_products function
-- Issue: Type mismatch between product_category ENUM and TEXT parameter
-- Solution: Add explicit type cast (::TEXT)

-- Drop existing function first (all overloads)
DROP FUNCTION IF EXISTS get_nearby_products(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT);
DROP FUNCTION IF EXISTS get_nearby_products(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, UUID);

-- Recreate function with type cast fix and current_user_id parameter
CREATE OR REPLACE FUNCTION get_nearby_products(
  user_lat DOUBLE PRECISION,
  user_lon DOUBLE PRECISION,
  radius_km DOUBLE PRECISION DEFAULT 20.0,
  product_category TEXT DEFAULT NULL,
  current_user_id UUID DEFAULT NULL
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
    pwl.category::TEXT,
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
    AND (product_category IS NULL OR pwl.category::TEXT = product_category)  -- Fix: Added ::TEXT cast
    AND (current_user_id IS NULL OR pwl.owner_id != current_user_id)  -- Don't show own products
  ORDER BY distance_km ASC, pwl.created_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_nearby_products IS 'Get available products within specified radius (default 20km) sorted by distance';

-- Test query (optional - uncomment to test)
-- Replace coordinates with your actual location
-- SELECT * FROM get_nearby_products(-0.903939, 100.349375, 20.0);
