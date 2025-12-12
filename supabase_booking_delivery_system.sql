-- =====================================================
-- BOOKING DELIVERY & MANAGEMENT SYSTEM
-- Add delivery method, fee calculation, and booking workflow
-- =====================================================

-- 1. Create delivery_method ENUM type
DO $$ BEGIN
    CREATE TYPE delivery_method AS ENUM ('pickup', 'delivery');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

COMMENT ON TYPE delivery_method IS 'Delivery method: pickup (renter picks up) or delivery (owner delivers)';

-- 2. Add new columns to bookings table
ALTER TABLE bookings 
  ADD COLUMN IF NOT EXISTS delivery_method delivery_method DEFAULT 'pickup',
  ADD COLUMN IF NOT EXISTS delivery_fee DECIMAL(10, 2) DEFAULT 0 CHECK (delivery_fee >= 0),
  ADD COLUMN IF NOT EXISTS distance_km DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS renter_address TEXT,
  ADD COLUMN IF NOT EXISTS notes TEXT;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_bookings_owner_id ON bookings(owner_id);
CREATE INDEX IF NOT EXISTS idx_bookings_delivery_method ON bookings(delivery_method);

-- Add comments for documentation
COMMENT ON COLUMN bookings.delivery_method IS 'How product will be delivered: pickup or delivery';
COMMENT ON COLUMN bookings.delivery_fee IS 'Additional fee for delivery service (Rp 5,000 per 2km)';
COMMENT ON COLUMN bookings.distance_km IS 'Distance between owner and renter in kilometers';
COMMENT ON COLUMN bookings.owner_id IS 'Product owner ID for easy notification and filtering';
COMMENT ON COLUMN bookings.renter_address IS 'Delivery address if delivery method is selected';
COMMENT ON COLUMN bookings.notes IS 'Additional notes from renter';

-- 3. Create function to calculate delivery fee
-- Fee structure: Rp 5,000 per 2km (rounded up)
CREATE OR REPLACE FUNCTION calculate_delivery_fee(
  distance DOUBLE PRECISION
)
RETURNS DECIMAL AS $$
DECLARE
  base_fee DECIMAL := 5000; -- Rp 5,000
  distance_unit DECIMAL := 2.0; -- per 2km
  fee DECIMAL;
BEGIN
  -- If distance is null or 0, no fee
  IF distance IS NULL OR distance <= 0 THEN
    RETURN 0;
  END IF;
  
  -- Calculate fee: ceiling(distance / 2km) * Rp 5,000
  fee := CEIL(distance / distance_unit) * base_fee;
  
  RETURN fee;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION calculate_delivery_fee IS 'Calculate delivery fee: Rp 5,000 per 2km (rounded up)';

-- 4. Create trigger to auto-populate owner_id when booking is created
CREATE OR REPLACE FUNCTION set_booking_owner_id()
RETURNS TRIGGER AS $$
BEGIN
  -- Get owner_id from products table
  SELECT owner_id INTO NEW.owner_id
  FROM products
  WHERE id = NEW.product_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS trigger_set_booking_owner_id ON bookings;

CREATE TRIGGER trigger_set_booking_owner_id
  BEFORE INSERT ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION set_booking_owner_id();

COMMENT ON TRIGGER trigger_set_booking_owner_id ON bookings IS 'Auto-populate owner_id from products table';

-- 5. Create view for bookings with complete information
CREATE OR REPLACE VIEW bookings_with_details AS
SELECT 
  b.id,
  b.user_id,
  b.product_id,
  b.start_date,
  b.end_date,
  b.total_price,
  b.status,
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
JOIN profiles renter ON b.user_id = renter.id
LEFT JOIN profiles owner ON b.owner_id = owner.id;

COMMENT ON VIEW bookings_with_details IS 'Complete booking information with product, renter, and owner details';

-- 6. Create function to get bookings by status for owner
CREATE OR REPLACE FUNCTION get_owner_bookings(
  p_owner_id UUID,
  p_status TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  product_name TEXT,
  renter_name TEXT,
  renter_phone TEXT,
  start_date DATE,
  end_date DATE,
  total_price DECIMAL,
  status TEXT,
  delivery_method TEXT,
  delivery_fee DECIMAL,
  distance_km DOUBLE PRECISION,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    bd.product_name,
    bd.renter_name,
    bd.renter_phone,
    b.start_date,
    b.end_date,
    b.total_price,
    b.status::TEXT,
    b.delivery_method::TEXT,
    b.delivery_fee,
    b.distance_km,
    b.created_at
  FROM bookings b
  JOIN bookings_with_details bd ON b.id = bd.id
  WHERE b.owner_id = p_owner_id
    AND (p_status IS NULL OR b.status::TEXT = p_status)
  ORDER BY 
    CASE b.status::TEXT
      WHEN 'pending' THEN 1
      WHEN 'confirmed' THEN 2
      WHEN 'active' THEN 3
      WHEN 'completed' THEN 4
      WHEN 'cancelled' THEN 5
    END,
    b.created_at DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_owner_bookings IS 'Get all bookings for a product owner, optionally filtered by status';

-- 7. Update RLS policies to include owner_id checks
-- Drop old policy if exists
DROP POLICY IF EXISTS "Users and owners can update bookings" ON bookings;

-- Recreate with owner_id support
CREATE POLICY "Users and owners can update bookings"
    ON bookings
    FOR UPDATE
    USING (
        auth.uid() = user_id OR  -- Renter can update
        auth.uid() = owner_id     -- Owner can update
    );

-- 8. Example queries and usage

-- Calculate delivery fee for 7.5 km distance
-- SELECT calculate_delivery_fee(7.5); -- Returns 20000 (4 units * 5000)

-- Get all pending bookings for an owner
-- SELECT * FROM get_owner_bookings('owner-uuid-here', 'pending');

-- Get booking with full details
-- SELECT * FROM bookings_with_details WHERE id = 'booking-uuid-here';

-- Update booking status (owner confirms)
-- UPDATE bookings 
-- SET status = 'confirmed' 
-- WHERE id = 'booking-uuid-here' AND owner_id = auth.uid();

COMMIT;
