-- =====================================================
-- FIX: Payment Status Synchronization Issue
-- =====================================================
-- Problem: Payment status not synced between payments and bookings tables
-- Solution: Add trigger to auto-sync booking payment_status when payment updates
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '🔧 Starting Payment Status Sync Fix...';
END $$;

-- 1. CREATE FUNCTION: UPDATE BOOKING PAYMENT STATUS
-- =====================================================
CREATE OR REPLACE FUNCTION update_booking_payment_status()
RETURNS TRIGGER AS $$
BEGIN
  -- When payment is paid, update booking payment status
  IF NEW.status = 'paid' AND OLD.status != 'paid' THEN
    UPDATE bookings
    SET payment_status = 'paid', updated_at = NOW()
    WHERE id = NEW.booking_id;

    RAISE NOTICE 'Booking % payment status updated to paid', NEW.booking_id;
  END IF;

  -- When payment is failed/expired/cancelled, update booking
  IF NEW.status IN ('failed', 'expired', 'cancelled') THEN
    UPDATE bookings
    SET payment_status = NEW.status, updated_at = NOW()
    WHERE id = NEW.booking_id;

    RAISE NOTICE 'Booking % payment status updated to %', NEW.booking_id, NEW.status;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. CREATE TRIGGER: AUTO UPDATE BOOKING PAYMENT STATUS
-- =====================================================
DROP TRIGGER IF EXISTS update_booking_payment_status_trigger ON payments;
CREATE TRIGGER update_booking_payment_status_trigger
  AFTER UPDATE ON payments
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION update_booking_payment_status();

DO $$
BEGIN
    RAISE NOTICE '✅ Trigger created: update_booking_payment_status_trigger';
END $$;

-- 3. SYNC EXISTING DATA: Update bookings for already paid payments
-- =====================================================
UPDATE bookings
SET payment_status = 'paid', updated_at = NOW()
WHERE id IN (
    SELECT DISTINCT p.booking_id
    FROM payments p
    WHERE p.status = 'paid'
      AND p.booking_id IS NOT NULL
)
AND (payment_status IS NULL OR payment_status != 'paid');

DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '✅ Synced % existing bookings with paid payment status', updated_count;
END $$;

-- 4. VERIFICATION: Check trigger exists
-- =====================================================
DO $$
DECLARE
    trigger_exists BOOLEAN;
    function_exists BOOLEAN;
BEGIN
    -- Check trigger
    SELECT EXISTS(
        SELECT 1 FROM pg_trigger
        WHERE tgname = 'update_booking_payment_status_trigger'
    ) INTO trigger_exists;

    -- Check function
    SELECT EXISTS(
        SELECT 1 FROM pg_proc
        WHERE proname = 'update_booking_payment_status'
    ) INTO function_exists;

    IF trigger_exists AND function_exists THEN
        RAISE NOTICE '✅ VERIFICATION: Payment sync trigger and function are active';
    ELSE
        RAISE NOTICE '❌ VERIFICATION: Trigger or function missing!';
        RAISE NOTICE '   Trigger exists: %', trigger_exists;
        RAISE NOTICE '   Function exists: %', function_exists;
    END IF;
END $$;

-- 5. TEST: Show sample data
-- =====================================================
DO $$
DECLARE
    booking_count INTEGER;
    payment_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO booking_count
    FROM bookings
    WHERE payment_status = 'paid';

    SELECT COUNT(*) INTO payment_count
    FROM payments
    WHERE status = 'paid';

    RAISE NOTICE '📊 Current Status:';
    RAISE NOTICE '   Bookings with payment_status=paid: %', booking_count;
    RAISE NOTICE '   Payments with status=paid: %', payment_count;

    IF booking_count = payment_count THEN
        RAISE NOTICE '✅ Status: Payment status is synchronized';
    ELSE
        RAISE NOTICE '⚠️  Status: Payment status may be out of sync (% vs %)', booking_count, payment_count;
    END IF;
END $$;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '🎉 PAYMENT SYNC FIX COMPLETE!';
    RAISE NOTICE '==========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'What was fixed:';
    RAISE NOTICE '1. ✅ Added trigger to auto-sync booking payment_status';
    RAISE NOTICE '2. ✅ Synced existing paid payments to bookings';
    RAISE NOTICE '';
    RAISE NOTICE 'How it works:';
    RAISE NOTICE '- When payment.status changes to paid, booking.payment_status also updates';
    RAISE NOTICE '- Both owner booking screen and detail screen will show consistent status';
    RAISE NOTICE '';
    RAISE NOTICE 'Test the fix:';
    RAISE NOTICE '1. Check owner booking management screen';
    RAISE NOTICE '2. Tap on booking card to go to detail screen';
    RAISE NOTICE '3. Both should show "Pembayaran Diterima" or payment completed';
    RAISE NOTICE '==========================================';
END $$;