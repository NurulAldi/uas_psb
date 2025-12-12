-- =====================================================
-- FIX PAYMENT RLS POLICIES
-- =====================================================
-- Purpose: Perbaiki RLS agar payment bisa di-update oleh user
--          dan bisa dilihat oleh owner produk
-- Created: 2025-12-11
-- =====================================================

-- Drop existing policies
DROP POLICY IF EXISTS "System can update payments" ON payments;
DROP POLICY IF EXISTS "Users can view own payments" ON payments;

-- =====================================================
-- POLICY: Users can view their own payments (as renter)
-- =====================================================
CREATE POLICY "Users can view own payments"
  ON payments FOR SELECT
  USING (
    booking_id IN (
      SELECT id FROM bookings WHERE user_id = auth.uid()
    )
  );

-- =====================================================
-- POLICY: Product owners can view payments for their products
-- =====================================================
CREATE POLICY "Owners can view payments for their products"
  ON payments FOR SELECT
  USING (
    booking_id IN (
      SELECT b.id 
      FROM bookings b
      JOIN products p ON b.product_id = p.id
      WHERE p.owner_id = auth.uid()
    )
  );

-- =====================================================
-- POLICY: Users can update their own payments
-- =====================================================
CREATE POLICY "Users can update own payments"
  ON payments FOR UPDATE
  USING (
    booking_id IN (
      SELECT id FROM bookings WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    booking_id IN (
      SELECT id FROM bookings WHERE user_id = auth.uid()
    )
  );

-- =====================================================
-- POLICY: Service role can update any payment (for webhooks)
-- =====================================================
-- Note: This is automatically handled by service_role bypass
-- But we add it explicitly for clarity

-- =====================================================
-- VERIFY POLICIES
-- =====================================================
-- Check all policies on payments table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'payments'
ORDER BY policyname;

COMMENT ON POLICY "Users can view own payments" ON payments IS 
  'Allows users to view payments for their own bookings';

COMMENT ON POLICY "Owners can view payments for their products" ON payments IS 
  'Allows product owners to see payment status for bookings of their products';

COMMENT ON POLICY "Users can update own payments" ON payments IS 
  'Allows users to update payment status for their own bookings (e.g., after QR download)';
