-- =====================================================
-- FIX: Replace PROFILES references with USERS table
-- =====================================================
-- Purpose: Fix "Could not find the table 'public.profiles'" error
-- The database uses 'users' table, not 'profiles'
-- =====================================================

-- Step 1: Drop the existing view
DROP VIEW IF EXISTS bookings_with_details CASCADE;

-- Step 2: Recreate the view with correct table references (users instead of profiles)
CREATE VIEW bookings_with_details AS
SELECT 
  b.id,
  b.user_id,
  b.product_id,
  b.start_date,
  b.end_date,
  b.total_price,
  b.status,
  b.payment_status,
  b.payment_proof_url,
  b.delivery_method,
  b.delivery_fee,
  b.distance_km,
  b.owner_id,
  b.renter_address,
  b.notes,
  b.created_at,
  b.updated_at,
  
  -- Product info
  p.name AS product_name,
  p.category AS product_category,
  p.price_per_day AS product_price,
  p.image_url AS product_image,
  
  -- Renter (user) info
  renter.full_name AS renter_name,
  renter.phone_number AS renter_phone,
  renter.email AS renter_email,
  renter.avatar_url AS renter_avatar,
  renter.city AS renter_city,
  renter.latitude AS renter_lat,
  renter.longitude AS renter_lon,
  
  -- Owner info
  owner.full_name AS owner_name,
  owner.phone_number AS owner_phone,
  owner.email AS owner_email,
  owner.avatar_url AS owner_avatar,
  owner.city AS owner_city,
  owner.latitude AS owner_lat,
  owner.longitude AS owner_lon,
  
  -- Calculated fields
  (b.end_date - b.start_date) AS duration_days,
  (b.total_price - COALESCE(b.delivery_fee, 0)) AS product_subtotal
  
FROM bookings b
JOIN products p ON b.product_id = p.id
JOIN users renter ON b.user_id = renter.id
LEFT JOIN users owner ON b.owner_id = owner.id;

COMMENT ON VIEW bookings_with_details IS 'Complete booking information with product, renter, owner details, and payment status (FIXED: uses users table)';

-- Step 3: Verify the view works
SELECT 
  id, 
  status, 
  payment_status, 
  product_name, 
  renter_name,
  owner_name
FROM bookings_with_details
LIMIT 5;
