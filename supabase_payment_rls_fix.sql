-- =====================================================
-- FIX: Update payments RLS policies for custom authentication
-- =====================================================
-- Issue: The payments table policies use auth.uid() but the app
--        uses custom authentication with session variables
-- =====================================================

-- Drop the old policies that use auth.uid()
DROP POLICY IF EXISTS "Users can view own payments" ON payments;
DROP POLICY IF EXISTS "Users can create own payments" ON payments;
DROP POLICY IF EXISTS "Users can update own payments" ON payments;
DROP POLICY IF EXISTS "Owners can view payments for their products" ON payments;

-- Create new policies that use session context (compatible with custom auth)

-- Policy: Users can view their own payments (as renter)
CREATE POLICY "Users can view own payments"
    ON payments FOR SELECT
    USING (
        booking_id IN (
            SELECT id FROM bookings
            WHERE user_id = (current_setting('app.current_user_id', true)::UUID)
        )
    );

-- Policy: Product owners can view payments for their products
CREATE POLICY "Owners can view payments for their products"
    ON payments FOR SELECT
    USING (
        booking_id IN (
            SELECT b.id FROM bookings b
            JOIN products p ON b.product_id = p.id
            WHERE p.owner_id = (current_setting('app.current_user_id', true)::UUID)
        )
    );

-- Policy: Users can create payments for their bookings
CREATE POLICY "Users can create own payments"
    ON payments FOR INSERT
    WITH CHECK (
        booking_id IN (
            SELECT id FROM bookings
            WHERE user_id = (current_setting('app.current_user_id', true)::UUID)
        )
    );

-- Policy: Users can update their own payments
CREATE POLICY "Users can update own payments"
    ON payments FOR UPDATE
    USING (
        booking_id IN (
            SELECT id FROM bookings
            WHERE user_id = (current_setting('app.current_user_id', true)::UUID)
        )
    )
    WITH CHECK (
        booking_id IN (
            SELECT id FROM bookings
            WHERE user_id = (current_setting('app.current_user_id', true)::UUID)
        )
    );

-- Keep the system update policy (for webhooks)
-- Keep the admin view policy

COMMENT ON POLICY "Users can view own payments" ON payments IS 'Users can view payments for bookings they created (session context)';
COMMENT ON POLICY "Owners can view payments for their products" ON payments IS 'Product owners can view payments for their products (session context)';
COMMENT ON POLICY "Users can create own payments" ON payments IS 'Users can create payments for their bookings (session context)';
COMMENT ON POLICY "Users can update own payments" ON payments IS 'Users can update their own payments (session context)';

-- =====================================================
-- ✅ PAYMENTS RLS POLICY FIX COMPLETE
-- =====================================================