-- =====================================================
-- TEST PAYMENT FLOW
-- =====================================================
-- Purpose: Test complete payment flow dari booking sampai payment
-- Created: 2025-12-11
-- =====================================================

-- =====================================================
-- 1. SETUP: Insert test data
-- =====================================================

-- Insert test user (renter)
INSERT INTO auth.users (id, email) 
VALUES ('11111111-1111-1111-1111-111111111111', 'renter@test.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (id, name, email) 
VALUES ('11111111-1111-1111-1111-111111111111', 'Test Renter', 'renter@test.com')
ON CONFLICT (id) DO NOTHING;

-- Insert test user (owner)
INSERT INTO auth.users (id, email) 
VALUES ('22222222-2222-2222-2222-222222222222', 'owner@test.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (id, name, email) 
VALUES ('22222222-2222-2222-2222-222222222222', 'Test Owner', 'owner@test.com')
ON CONFLICT (id) DO NOTHING;

-- Insert test product
INSERT INTO products (id, name, owner_id, category, price_per_day, is_available)
VALUES (
  '33333333-3333-3333-3333-333333333333',
  'Test Camera',
  '22222222-2222-2222-2222-222222222222',
  'camera',
  100000,
  true
)
ON CONFLICT (id) DO NOTHING;

-- Insert test booking
INSERT INTO bookings (
  id, 
  user_id, 
  product_id, 
  start_date, 
  end_date, 
  total_price, 
  status,
  payment_status
)
VALUES (
  '44444444-4444-4444-4444-444444444444',
  '11111111-1111-1111-1111-111111111111',
  '33333333-3333-3333-3333-333333333333',
  CURRENT_DATE + INTERVAL '1 day',
  CURRENT_DATE + INTERVAL '3 days',
  200000,
  'pending',
  'pending'
)
ON CONFLICT (id) DO NOTHING;

-- Insert test payment
INSERT INTO payments (
  id,
  booking_id,
  order_id,
  amount,
  status,
  method
)
VALUES (
  '55555555-5555-5555-5555-555555555555',
  '44444444-4444-4444-4444-444444444444',
  'ORDER-TEST-12345',
  200000,
  'pending',
  'qris'
)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- 2. VERIFY: Check initial state
-- =====================================================
SELECT 
  '=== INITIAL STATE ===' as stage,
  b.id as booking_id,
  b.payment_status as booking_payment_status,
  p.id as payment_id,
  p.status as payment_status,
  p.paid_at
FROM bookings b
LEFT JOIN payments p ON b.id = p.booking_id
WHERE b.id = '44444444-4444-4444-4444-444444444444';

-- =====================================================
-- 3. SIMULATE: User downloads QR and payment settles
-- =====================================================
UPDATE payments
SET 
  status = 'paid',
  transaction_id = 'TXN-TEST-67890',
  fraud_status = 'accept',
  paid_at = NOW(),
  updated_at = NOW()
WHERE order_id = 'ORDER-TEST-12345';

-- =====================================================
-- 4. VERIFY: Check after payment update
-- =====================================================
SELECT 
  '=== AFTER PAYMENT UPDATE ===' as stage,
  b.id as booking_id,
  b.payment_status as booking_payment_status,
  p.id as payment_id,
  p.status as payment_status,
  p.paid_at,
  p.transaction_id
FROM bookings b
LEFT JOIN payments p ON b.id = p.booking_id
WHERE b.id = '44444444-4444-4444-4444-444444444444';

-- =====================================================
-- 5. TEST: Can renter see payment?
-- =====================================================
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "11111111-1111-1111-1111-111111111111"}';

SELECT 
  '=== RENTER VIEW ===' as stage,
  id,
  order_id,
  status,
  amount,
  paid_at
FROM payments
WHERE order_id = 'ORDER-TEST-12345';

RESET role;

-- =====================================================
-- 6. TEST: Can owner see payment?
-- =====================================================
SET LOCAL role TO authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "22222222-2222-2222-2222-222222222222"}';

SELECT 
  '=== OWNER VIEW ===' as stage,
  p.id,
  p.order_id,
  p.status,
  p.amount,
  p.paid_at,
  b.user_id as renter_id
FROM payments p
JOIN bookings b ON p.booking_id = b.id
JOIN products prod ON b.product_id = prod.id
WHERE prod.owner_id = '22222222-2222-2222-2222-222222222222';

RESET role;

-- =====================================================
-- 7. TEST: Payment view for owner (via bookings_with_details)
-- =====================================================
SELECT 
  '=== OWNER BOOKING VIEW ===' as stage,
  id as booking_id,
  product_name,
  renter_name,
  total_price,
  status as booking_status,
  payment_status
FROM bookings_with_details
WHERE owner_id = '22222222-2222-2222-2222-222222222222'
  AND id = '44444444-4444-4444-4444-444444444444';

-- =====================================================
-- 8. CLEANUP (optional - comment out if you want to keep test data)
-- =====================================================
/*
DELETE FROM payments WHERE id = '55555555-5555-5555-5555-555555555555';
DELETE FROM bookings WHERE id = '44444444-4444-4444-4444-444444444444';
DELETE FROM products WHERE id = '33333333-3333-3333-3333-333333333333';
DELETE FROM profiles WHERE id IN (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222'
);
*/

-- =====================================================
-- EXPECTED RESULTS:
-- =====================================================
-- 1. INITIAL STATE: 
--    - booking_payment_status = 'pending'
--    - payment_status = 'pending'
--    - paid_at = NULL
--
-- 2. AFTER PAYMENT UPDATE:
--    - booking_payment_status = 'paid' (updated by trigger!)
--    - payment_status = 'paid'
--    - paid_at = NOW()
--    - transaction_id = 'TXN-TEST-67890'
--
-- 3. RENTER VIEW:
--    - Should see 1 row (their own payment)
--
-- 4. OWNER VIEW:
--    - Should see 1 row (payment for their product)
--
-- 5. OWNER BOOKING VIEW:
--    - Should see booking with payment_status = 'paid'
