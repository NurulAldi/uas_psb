-- =====================================================
-- FIX: Update bookings RLS policy for custom authentication
-- =====================================================
-- Issue: The booking creation policy uses auth.uid() but the app
--        uses custom authentication with session variables
-- =====================================================

-- Drop the old policy that uses auth.uid()
DROP POLICY IF EXISTS "Users can create bookings" ON bookings;

-- Create new policy that uses session context (compatible with custom auth)
CREATE POLICY "Users can create bookings"
    ON bookings
    FOR INSERT
    WITH CHECK (
        user_id = (current_setting('app.current_user_id', true)::UUID)
        AND user_id IS NOT NULL
    );

-- Also update other booking policies to be consistent
DROP POLICY IF EXISTS "Users and owners can update bookings" ON bookings;
CREATE POLICY "Users and owners can update bookings"
    ON bookings
    FOR UPDATE
    USING (
        user_id = (current_setting('app.current_user_id', true)::UUID)
        OR product_id IN (
            SELECT id FROM products
            WHERE owner_id = (current_setting('app.current_user_id', true)::UUID)
        )
    )
    WITH CHECK (
        user_id = (current_setting('app.current_user_id', true)::UUID)
        OR product_id IN (
            SELECT id FROM products
            WHERE owner_id = (current_setting('app.current_user_id', true)::UUID)
        )
    );

DROP POLICY IF EXISTS "Users can delete their own bookings" ON bookings;
CREATE POLICY "Users can delete their own bookings"
    ON bookings
    FOR DELETE
    USING (user_id = (current_setting('app.current_user_id', true)::UUID));

-- Keep the view policy as is (anyone can view)
-- Keep the banned users policy as is

COMMENT ON POLICY "Users can create bookings" ON bookings IS 'Users can create bookings using session context (custom auth compatible)';
COMMENT ON POLICY "Users and owners can update bookings" ON bookings IS 'Both renter and owner can manage booking status using session context';
COMMENT ON POLICY "Users can delete their own bookings" ON bookings IS 'Users can cancel their bookings using session context';

-- =====================================================
-- ✅ BOOKING RLS POLICY FIX COMPLETE
-- =====================================================