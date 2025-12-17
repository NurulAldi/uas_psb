-- =====================================================
-- ALTERNATIVE FIX: Tanpa Mengubah Storage.Objects
-- =====================================================
-- Problem: User tidak punya permission untuk ALTER storage.objects
-- Solution: Hanya fix database view, storage setup via Dashboard
-- =====================================================

-- =====================================================
-- PART 1: FIX DATABASE VIEW (profiles → users)
-- =====================================================
-- Ini BISA dijalankan oleh user biasa

DO $$ 
BEGIN
    RAISE NOTICE '🔧 Starting Database View Fix...';
END $$;

-- Drop existing view
DROP VIEW IF EXISTS bookings_with_details CASCADE;

-- Recreate view dengan table 'users' (bukan 'profiles')
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
  
  -- Renter (user) info - FIXED: uses 'users' table
  renter.full_name AS renter_name,
  renter.phone_number AS renter_phone,
  renter.email AS renter_email,
  renter.avatar_url AS renter_avatar,
  renter.city AS renter_city,
  renter.latitude AS renter_lat,
  renter.longitude AS renter_lon,
  
  -- Owner info - FIXED: uses 'users' table
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

COMMENT ON VIEW bookings_with_details IS 
  'Complete booking information - FIXED: uses users table instead of profiles';

DO $$ 
BEGIN
    RAISE NOTICE '✅ Database View Fix: DONE';
    RAISE NOTICE '   - View bookings_with_details recreated';
    RAISE NOTICE '   - Using users table instead of profiles';
END $$;

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$ 
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Running Verification Tests...';
END $$;

-- Test: Check view exists and uses users table
DO $$
DECLARE
    view_exists BOOLEAN;
    uses_users_table BOOLEAN;
    record_count INTEGER;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM information_schema.views 
        WHERE table_name = 'bookings_with_details'
    ) INTO view_exists;
    
    SELECT EXISTS(
        SELECT 1 FROM pg_views 
        WHERE viewname = 'bookings_with_details' 
        AND definition LIKE '%users renter%'
    ) INTO uses_users_table;
    
    SELECT COUNT(*) FROM bookings_with_details INTO record_count;
    
    IF view_exists AND uses_users_table THEN
        RAISE NOTICE '✅ View bookings_with_details: OK';
        RAISE NOTICE '   - Uses users table: YES';
        RAISE NOTICE '   - Records found: %', record_count;
    ELSE
        RAISE NOTICE '❌ View issue detected';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '⚠️  View test error: %', SQLERRM;
END $$;

-- =====================================================
-- SUMMARY & NEXT STEPS
-- =====================================================

DO $$ 
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '✅ DATABASE VIEW FIX: COMPLETE!';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'What was fixed:';
    RAISE NOTICE '✅ View bookings_with_details → uses users table';
    RAISE NOTICE '✅ Halaman Permintaan Booking → should work now';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  STORAGE FIX: Requires Manual Setup';
    RAISE NOTICE '';
    RAISE NOTICE 'For fixing upload images, follow these steps:';
    RAISE NOTICE '1. Go to Supabase Dashboard';
    RAISE NOTICE '2. Navigate to: Storage → Buckets';
    RAISE NOTICE '3. Find bucket: product-images';
    RAISE NOTICE '4. Click configuration (gear icon)';
    RAISE NOTICE '5. Set: Public bucket = ON';
    RAISE NOTICE '6. Go to: Policies tab';
    RAISE NOTICE '7. Click: New Policy → Custom';
    RAISE NOTICE '8. Add policy for INSERT:';
    RAISE NOTICE '   Name: Allow all inserts';
    RAISE NOTICE '   Target: INSERT';
    RAISE NOTICE '   Policy: true (or just leave empty)';
    RAISE NOTICE '9. Save policy';
    RAISE NOTICE '';
    RAISE NOTICE 'Alternatively, create bucket fresh:';
    RAISE NOTICE '1. Delete old product-images bucket (if exists)';
    RAISE NOTICE '2. Create New Bucket:';
    RAISE NOTICE '   - Name: product-images';
    RAISE NOTICE '   - Public: ON';
    RAISE NOTICE '   - File size limit: 5MB';
    RAISE NOTICE '   - Allowed MIME types: image/*';
    RAISE NOTICE '3. Done! Upload will work automatically';
    RAISE NOTICE '';
    RAISE NOTICE 'Test:';
    RAISE NOTICE '1. Restart Flutter app';
    RAISE NOTICE '2. Test halaman Permintaan Booking ✅';
    RAISE NOTICE '3. Test upload gambar produk (after storage setup)';
    RAISE NOTICE '==========================================';
END $$;
