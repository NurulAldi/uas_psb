-- =====================================================
-- MIDTRANS QRIS PAYMENT SYSTEM MIGRATION
-- =====================================================
-- Purpose: Add payment functionality with Midtrans QRIS
-- Created: 2025-12-10
-- =====================================================

-- 1. CREATE PAYMENT STATUS ENUM
-- =====================================================
DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM (
    'pending',
    'processing',
    'paid',
    'failed',
    'expired',
    'cancelled'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- 2. CREATE PAYMENT METHOD ENUM
-- =====================================================
DO $$ BEGIN
  CREATE TYPE payment_method AS ENUM (
    'qris',
    'gopay',
    'shopeepay',
    'bank_transfer'
  );
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- 3. CREATE PAYMENTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  order_id VARCHAR(255) UNIQUE NOT NULL, -- Midtrans order ID
  amount BIGINT NOT NULL CHECK (amount > 0), -- Amount in IDR
  status payment_status DEFAULT 'pending' NOT NULL,
  method payment_method DEFAULT 'qris' NOT NULL,
  snap_token TEXT, -- Midtrans Snap token
  snap_url TEXT, -- Midtrans payment URL
  transaction_id VARCHAR(255), -- Midtrans transaction ID
  fraud_status VARCHAR(50), -- Midtrans fraud status
  paid_at TIMESTAMP WITH TIME ZONE, -- When payment was completed
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- 4. CREATE INDEXES FOR PERFORMANCE
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_payments_booking_id ON payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_transaction_id ON payments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at DESC);

-- 5. ADD PAYMENT STATUS TO BOOKINGS TABLE
-- =====================================================
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS payment_status payment_status DEFAULT 'pending';

-- Create index on payment_status
CREATE INDEX IF NOT EXISTS idx_bookings_payment_status ON bookings(payment_status);

-- 6. CREATE FUNCTION: UPDATE BOOKING PAYMENT STATUS
-- =====================================================
CREATE OR REPLACE FUNCTION update_booking_payment_status()
RETURNS TRIGGER AS $$
BEGIN
  -- When payment is paid, update booking payment status
  IF NEW.status = 'paid' AND OLD.status != 'paid' THEN
    UPDATE bookings
    SET payment_status = 'paid'
    WHERE id = NEW.booking_id;
    
    RAISE NOTICE 'Booking % payment status updated to paid', NEW.booking_id;
  END IF;
  
  -- When payment is failed/expired/cancelled, update booking
  IF NEW.status IN ('failed', 'expired', 'cancelled') THEN
    UPDATE bookings
    SET payment_status = NEW.status
    WHERE id = NEW.booking_id;
    
    RAISE NOTICE 'Booking % payment status updated to %', NEW.booking_id, NEW.status;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. CREATE TRIGGER: AUTO UPDATE BOOKING PAYMENT STATUS
-- =====================================================
DROP TRIGGER IF EXISTS update_booking_payment_status_trigger ON payments;
CREATE TRIGGER update_booking_payment_status_trigger
  AFTER UPDATE ON payments
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION update_booking_payment_status();

-- 8. CREATE FUNCTION: UPDATE PAYMENT UPDATED_AT
-- =====================================================
CREATE OR REPLACE FUNCTION update_payment_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 9. CREATE TRIGGER: AUTO UPDATE PAYMENT UPDATED_AT
-- =====================================================
DROP TRIGGER IF EXISTS update_payment_updated_at_trigger ON payments;
CREATE TRIGGER update_payment_updated_at_trigger
  BEFORE UPDATE ON payments
  FOR EACH ROW
  EXECUTE FUNCTION update_payment_updated_at();

-- 10. CREATE RPC: GET PAYMENT BY BOOKING ID
-- =====================================================
CREATE OR REPLACE FUNCTION get_payment_by_booking(booking_id_param UUID)
RETURNS TABLE (
  id UUID,
  booking_id UUID,
  order_id VARCHAR,
  amount BIGINT,
  status payment_status,
  method payment_method,
  snap_token TEXT,
  snap_url TEXT,
  transaction_id VARCHAR,
  fraud_status VARCHAR,
  paid_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.booking_id,
    p.order_id,
    p.amount,
    p.status,
    p.method,
    p.snap_token,
    p.snap_url,
    p.transaction_id,
    p.fraud_status,
    p.paid_at,
    p.created_at,
    p.updated_at
  FROM payments p
  WHERE p.booking_id = booking_id_param
  ORDER BY p.created_at DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. CREATE VIEW: BOOKINGS WITH PAYMENT INFO
-- =====================================================
CREATE OR REPLACE VIEW bookings_with_payment AS
SELECT 
  b.id,
  b.user_id,
  b.product_id,
  b.start_date,
  b.end_date,
  b.total_price,
  b.status AS booking_status,
  b.payment_status AS booking_payment_status,
  b.delivery_method,
  b.renter_address,
  b.delivery_fee,
  b.notes,
  b.created_at AS booking_created_at,
  b.updated_at AS booking_updated_at,
  p.id AS payment_id,
  p.order_id AS payment_order_id,
  p.amount AS payment_amount,
  p.status AS payment_status,
  p.method AS payment_method,
  p.snap_token AS payment_snap_token,
  p.snap_url AS payment_snap_url,
  p.transaction_id AS payment_transaction_id,
  p.paid_at AS payment_paid_at,
  p.created_at AS payment_created_at,
  prod.name AS product_name,
  prod.image_url AS product_image_url,
  prod.price_per_day AS product_price_per_day,
  prof.full_name AS user_name,
  prof.email AS user_email
FROM bookings b
LEFT JOIN payments p ON b.id = p.booking_id
LEFT JOIN products prod ON b.product_id = prod.id
LEFT JOIN profiles prof ON b.user_id = prof.id;

-- 12. ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on payments table
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own payments
CREATE POLICY "Users can view own payments"
  ON payments FOR SELECT
  USING (
    booking_id IN (
      SELECT id FROM bookings WHERE user_id = auth.uid()
    )
  );

-- Policy: Users can insert their own payments
CREATE POLICY "Users can create own payments"
  ON payments FOR INSERT
  WITH CHECK (
    booking_id IN (
      SELECT id FROM bookings WHERE user_id = auth.uid()
    )
  );

-- Policy: System can update payments (for webhook)
CREATE POLICY "System can update payments"
  ON payments FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- Policy: Admins can view all payments
CREATE POLICY "Admins can view all payments"
  ON payments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 13. GRANT PERMISSIONS
-- =====================================================
GRANT ALL ON payments TO authenticated;
GRANT ALL ON payments TO service_role;

-- 14. CREATE SAMPLE COMMENT
-- =====================================================
COMMENT ON TABLE payments IS 'Stores payment transactions for bookings using Midtrans QRIS';
COMMENT ON COLUMN payments.order_id IS 'Unique order ID for Midtrans transaction';
COMMENT ON COLUMN payments.snap_token IS 'Midtrans Snap token for payment page';
COMMENT ON COLUMN payments.transaction_id IS 'Midtrans transaction ID after payment';
COMMENT ON COLUMN payments.fraud_status IS 'Midtrans fraud detection status';

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- Next steps:
-- 1. Run this SQL in Supabase SQL Editor
-- 2. Verify tables and functions are created
-- 3. Test payment flow in application
-- =====================================================
