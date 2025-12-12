-- =====================================================
-- BOOKING STATUS SYNC FIX
-- Pastikan payment_status sudah ada dan synchronized
-- =====================================================

-- 1. Verify payment_status column exists in bookings table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'bookings' 
    AND column_name = 'payment_status'
  ) THEN
    -- Add payment_status column if not exists
    ALTER TABLE bookings ADD COLUMN payment_status payment_status DEFAULT 'pending';
    RAISE NOTICE 'Added payment_status column to bookings table';
  ELSE
    RAISE NOTICE 'payment_status column already exists';
  END IF;
END $$;

-- 2. Create index if not exists
CREATE INDEX IF NOT EXISTS idx_bookings_payment_status ON bookings(payment_status);

-- 3. Verify trigger exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'update_booking_payment_status_trigger'
  ) THEN
    -- Create trigger if not exists
    CREATE TRIGGER update_booking_payment_status_trigger
      AFTER UPDATE ON payments
      FOR EACH ROW
      WHEN (OLD.status IS DISTINCT FROM NEW.status)
      EXECUTE FUNCTION update_booking_payment_status();
    
    RAISE NOTICE 'Created update_booking_payment_status_trigger';
  ELSE
    RAISE NOTICE 'Trigger already exists';
  END IF;
END $$;

-- 4. Sync existing data (one-time fix)
-- Update payment_status based on existing payment records
UPDATE bookings b
SET payment_status = (
  SELECT p.status
  FROM payments p
  WHERE p.booking_id = b.id
  ORDER BY p.created_at DESC
  LIMIT 1
)
WHERE EXISTS (
  SELECT 1 FROM payments p WHERE p.booking_id = b.id
);

-- 5. Verify sync
-- Show bookings with their payment status
SELECT 
  b.id,
  b.status as booking_status,
  b.payment_status as booking_payment_status,
  p.status as payment_status,
  p.paid_at,
  b.created_at
FROM bookings b
LEFT JOIN payments p ON b.id = p.booking_id
ORDER BY b.created_at DESC
LIMIT 10;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check column exists
SELECT 
  table_name, 
  column_name, 
  data_type,
  column_default
FROM information_schema.columns
WHERE table_name = 'bookings' 
AND column_name = 'payment_status';

-- Check trigger exists
SELECT 
  tgname as trigger_name,
  tgenabled as enabled,
  tgtype
FROM pg_trigger
WHERE tgname = 'update_booking_payment_status_trigger';

-- Check function exists
SELECT 
  proname as function_name,
  prosrc as function_body
FROM pg_proc
WHERE proname = 'update_booking_payment_status';

COMMENT ON COLUMN bookings.payment_status IS 'Status pembayaran booking, di-sync otomatis dari payments table via trigger';
