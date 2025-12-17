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

-- =====================================================
-- ✅ VIEW FIX COMPLETE
-- =====================================================