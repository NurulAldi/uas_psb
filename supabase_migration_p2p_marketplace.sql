-- =====================================================
-- P2P Marketplace Migration Script
-- Convert RentLens to Peer-to-Peer Camera Rental Platform
-- =====================================================

-- =====================================================
-- STEP 1: BACKUP EXISTING DATA (OPTIONAL)
-- =====================================================
-- Uncomment below to create backup table before migration
-- CREATE TABLE products_backup AS SELECT * FROM products;

-- =====================================================
-- STEP 2: ADD OWNER_ID COLUMN TO PRODUCTS TABLE
-- =====================================================

-- Add owner_id column (initially nullable to allow data migration)
ALTER TABLE products 
ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES profiles(id) ON DELETE CASCADE;

-- Add index on owner_id for performance
CREATE INDEX IF NOT EXISTS idx_products_owner_id ON products(owner_id);

COMMENT ON COLUMN products.owner_id IS 'References the user (profile) who owns this camera equipment';

-- =====================================================
-- STEP 3: HANDLE EXISTING DATA
-- =====================================================

-- Option A: Delete all existing products (clean slate)
-- Uncomment if you want to start fresh
-- DELETE FROM products;

-- Option B: Create a default "platform" user and assign ownership
-- This preserves existing products
DO $$
DECLARE
    platform_user_id UUID;
BEGIN
    -- Check if any products exist without owner
    IF EXISTS (SELECT 1 FROM products WHERE owner_id IS NULL) THEN
        -- Try to find an existing user to assign as default owner
        SELECT id INTO platform_user_id 
        FROM profiles 
        ORDER BY created_at ASC 
        LIMIT 1;
        
        IF platform_user_id IS NOT NULL THEN
            -- Assign first registered user as owner of orphaned products
            UPDATE products 
            SET owner_id = platform_user_id 
            WHERE owner_id IS NULL;
            
            RAISE NOTICE 'Assigned % products to user: %', 
                (SELECT COUNT(*) FROM products WHERE owner_id = platform_user_id), 
                platform_user_id;
        ELSE
            -- No users exist, must delete products or create dummy user
            RAISE EXCEPTION 'No users found in profiles table. Cannot assign owner to existing products. Either delete products or create a user first.';
        END IF;
    END IF;
END $$;

-- =====================================================
-- STEP 4: MAKE OWNER_ID NOT NULL
-- =====================================================

-- Now that all products have an owner, make the column NOT NULL
ALTER TABLE products 
ALTER COLUMN owner_id SET NOT NULL;

-- =====================================================
-- STEP 5: DROP OLD RLS POLICIES
-- =====================================================

-- Drop the permissive development policy
DROP POLICY IF EXISTS "Allow all operations on products for development" ON products;

-- =====================================================
-- STEP 6: CREATE NEW RLS POLICIES FOR P2P MARKETPLACE
-- =====================================================

-- Policy 1: Anyone can view/read all products (public marketplace)
CREATE POLICY "Anyone can view all products"
    ON products
    FOR SELECT
    USING (true);

-- Policy 2: Authenticated users can insert their own products
CREATE POLICY "Users can create their own products"
    ON products
    FOR INSERT
    WITH CHECK (auth.uid() = owner_id);

-- Policy 3: Users can only update their own products
CREATE POLICY "Users can update their own products"
    ON products
    FOR UPDATE
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

-- Policy 4: Users can only delete their own products
CREATE POLICY "Users can delete their own products"
    ON products
    FOR DELETE
    USING (auth.uid() = owner_id);

-- =====================================================
-- STEP 7: ADD HELPFUL COMMENTS AND METADATA
-- =====================================================

COMMENT ON TABLE products IS 'P2P marketplace products - camera equipment owned by users';
COMMENT ON POLICY "Anyone can view all products" ON products IS 'Public marketplace - all products visible to everyone';
COMMENT ON POLICY "Users can create their own products" ON products IS 'Users can list their own equipment for rent';
COMMENT ON POLICY "Users can update their own products" ON products IS 'Users can only edit their own listings';
COMMENT ON POLICY "Users can delete their own products" ON products IS 'Users can only remove their own listings';

-- =====================================================
-- STEP 8: CREATE HELPER VIEWS (OPTIONAL)
-- =====================================================

-- View: Products with owner information
CREATE OR REPLACE VIEW products_with_owner AS
SELECT 
    p.*,
    prof.full_name as owner_name,
    prof.email as owner_email,
    prof.phone_number as owner_phone,
    prof.avatar_url as owner_avatar
FROM products p
LEFT JOIN profiles prof ON p.owner_id = prof.id;

COMMENT ON VIEW products_with_owner IS 'Products joined with owner profile information';

-- Grant access to the view
GRANT SELECT ON products_with_owner TO anon, authenticated;

-- =====================================================
-- STEP 9: CREATE FUNCTION TO GET USER'S PRODUCTS
-- =====================================================

-- Function: Get all products owned by current user
CREATE OR REPLACE FUNCTION get_my_products()
RETURNS SETOF products
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT * FROM products 
    WHERE owner_id = auth.uid()
    ORDER BY created_at DESC;
$$;

COMMENT ON FUNCTION get_my_products() IS 'Returns all products owned by the currently authenticated user';

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_my_products() TO authenticated;

-- =====================================================
-- STEP 10: UPDATE BOOKINGS TABLE RLS (OPTIONAL ENHANCEMENT)
-- =====================================================

-- Drop old permissive policy on bookings
DROP POLICY IF EXISTS "Allow all operations on bookings for development" ON bookings;

-- Policy: Anyone can view bookings (for transparency)
CREATE POLICY "Anyone can view bookings"
    ON bookings
    FOR SELECT
    USING (true);

-- Policy: Users can create bookings for any product
CREATE POLICY "Users can create bookings"
    ON bookings
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own bookings OR product owners can update bookings for their products
CREATE POLICY "Users and owners can update bookings"
    ON bookings
    FOR UPDATE
    USING (
        auth.uid() = user_id OR 
        auth.uid() IN (SELECT owner_id FROM products WHERE id = bookings.product_id)
    )
    WITH CHECK (
        auth.uid() = user_id OR 
        auth.uid() IN (SELECT owner_id FROM products WHERE id = bookings.product_id)
    );

-- Policy: Users can delete their own bookings
CREATE POLICY "Users can delete their own bookings"
    ON bookings
    FOR DELETE
    USING (auth.uid() = user_id);

COMMENT ON POLICY "Anyone can view bookings" ON bookings IS 'Transparent marketplace - all bookings visible';
COMMENT ON POLICY "Users can create bookings" ON bookings IS 'Users can rent any available product';
COMMENT ON POLICY "Users and owners can update bookings" ON bookings IS 'Both renter and owner can manage booking status';
COMMENT ON POLICY "Users can delete their own bookings" ON bookings IS 'Users can cancel their bookings';

-- =====================================================
-- STEP 11: VALIDATION QUERIES
-- =====================================================

-- Check that all products have an owner
DO $$
DECLARE
    orphaned_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO orphaned_count 
    FROM products 
    WHERE owner_id IS NULL;
    
    IF orphaned_count > 0 THEN
        RAISE EXCEPTION 'Migration failed: % products without owner_id', orphaned_count;
    ELSE
        RAISE NOTICE '✅ Migration successful: All products have an owner';
    END IF;
END $$;

-- Display migration summary
DO $$
BEGIN
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ P2P MARKETPLACE MIGRATION COMPLETE';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE 'Products table:';
    RAISE NOTICE '  - owner_id column: ADDED (NOT NULL, FK to profiles)';
    RAISE NOTICE '  - Total products: %', (SELECT COUNT(*) FROM products);
    RAISE NOTICE '';
    RAISE NOTICE 'RLS Policies:';
    RAISE NOTICE '  - SELECT: Public (anyone can view)';
    RAISE NOTICE '  - INSERT: Owner only (auth.uid() = owner_id)';
    RAISE NOTICE '  - UPDATE: Owner only (auth.uid() = owner_id)';
    RAISE NOTICE '  - DELETE: Owner only (auth.uid() = owner_id)';
    RAISE NOTICE '';
    RAISE NOTICE 'New Features:';
    RAISE NOTICE '  - View: products_with_owner';
    RAISE NOTICE '  - Function: get_my_products()';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '  1. Update Flutter app to include owner_id when creating products';
    RAISE NOTICE '  2. Add "My Listings" screen to show user''s products';
    RAISE NOTICE '  3. Add "Add Product" screen for users to list their equipment';
    RAISE NOTICE '  4. Update product detail screen to show owner info';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

-- =====================================================
-- MIGRATION SCRIPT COMPLETE
-- =====================================================

-- TESTING QUERIES (Run these to verify migration):
/*

-- 1. Check products table structure
\d products

-- 2. View all products with owner info
SELECT id, name, owner_id, is_available FROM products LIMIT 5;

-- 3. Test RLS - try to insert a product (must be authenticated)
-- This should work if auth.uid() matches owner_id
INSERT INTO products (name, category, description, price_per_day, owner_id, is_available)
VALUES ('Test Camera', 'DSLR', 'Test listing', 100000, auth.uid(), true);

-- 4. View products with owner details
SELECT * FROM products_with_owner LIMIT 5;

-- 5. Get current user's products (as authenticated user)
SELECT * FROM get_my_products();

-- 6. Check RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'products';

*/
