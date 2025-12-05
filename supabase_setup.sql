-- =====================================================
-- Camera Rental App - Database Setup Script
-- PostgreSQL for Supabase
-- =====================================================

-- =====================================================
-- 1. CREATE ENUM TYPES
-- =====================================================

-- Create enum for product categories
CREATE TYPE product_category AS ENUM ('DSLR', 'Mirrorless', 'Drone', 'Lens');

-- Create enum for booking status
CREATE TYPE booking_status AS ENUM ('pending', 'confirmed', 'active', 'completed', 'cancelled');

-- =====================================================
-- 2. CREATE TABLES
-- =====================================================

-- Profiles Table (extends auth.users)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    phone_number TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Products Table
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category product_category NOT NULL,
    description TEXT,
    price_per_day DECIMAL(10, 2) NOT NULL CHECK (price_per_day > 0),
    image_url TEXT,
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Bookings Table
CREATE TABLE IF NOT EXISTS bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL CHECK (total_price >= 0),
    status booking_status DEFAULT 'pending',
    payment_proof_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT valid_date_range CHECK (end_date > start_date)
);

-- =====================================================
-- 3. CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Index on profiles email for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);

-- Index on products category and availability for filtering
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_is_available ON products(is_available);

-- Index on bookings for common queries
CREATE INDEX IF NOT EXISTS idx_bookings_user_id ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_product_id ON bookings(product_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_dates ON bookings(start_date, end_date);

-- =====================================================
-- 4. CREATE FUNCTIONS & TRIGGERS
-- =====================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at on all tables
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bookings_updated_at
    BEFORE UPDATE ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically create profile when user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user signup
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- =====================================================
-- 5. ENABLE ROW LEVEL SECURITY (RLS)
-- =====================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 6. CREATE RLS POLICIES (PERMISSIVE FOR DEVELOPMENT)
-- =====================================================

-- Profiles: Allow all operations for development
CREATE POLICY "Allow all operations on profiles for development"
    ON profiles
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Products: Allow all operations for development
CREATE POLICY "Allow all operations on products for development"
    ON products
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Bookings: Allow all operations for development
CREATE POLICY "Allow all operations on bookings for development"
    ON bookings
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- =====================================================
-- 7. GRANT PERMISSIONS
-- =====================================================

-- Grant usage on schemas
GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- Grant permissions on tables
GRANT ALL ON profiles TO anon, authenticated;
GRANT ALL ON products TO anon, authenticated;
GRANT ALL ON bookings TO anon, authenticated;

-- Grant permissions on sequences (for UUID generation)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

-- =====================================================
-- 8. INSERT SAMPLE DATA (OPTIONAL)
-- =====================================================

-- Sample Products (uncomment if you want sample data)
/*
INSERT INTO products (name, category, description, price_per_day, image_url, is_available) VALUES
('Canon EOS R5', 'Mirrorless', 'Professional full-frame mirrorless camera with 45MP sensor', 150000, 'https://example.com/canon-r5.jpg', true),
('Sony A7 IV', 'Mirrorless', 'Versatile full-frame mirrorless camera with 33MP sensor', 120000, 'https://example.com/sony-a7iv.jpg', true),
('Nikon D850', 'DSLR', 'Professional DSLR with 45.7MP sensor', 100000, 'https://example.com/nikon-d850.jpg', true),
('DJI Mavic 3', 'Drone', 'Professional drone with Hasselblad camera', 200000, 'https://example.com/dji-mavic3.jpg', true),
('Canon RF 24-70mm f/2.8L', 'Lens', 'Professional standard zoom lens', 50000, 'https://example.com/canon-rf-24-70.jpg', true),
('Sony FE 70-200mm f/2.8 GM', 'Lens', 'Professional telephoto zoom lens', 80000, 'https://example.com/sony-70-200.jpg', true);
*/

-- =====================================================
-- SCRIPT COMPLETE
-- =====================================================

-- Note: After running this script in Supabase SQL Editor:
-- 1. Verify all tables are created successfully
-- 2. Test RLS policies with different user roles
-- 3. Consider tightening RLS policies for production
-- 4. Set up storage buckets for images (avatar_url, image_url, payment_proof_url)
-- 5. Configure Supabase Auth settings as needed
