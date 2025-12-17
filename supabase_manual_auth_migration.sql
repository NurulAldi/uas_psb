-- ============================================================================
-- MANUAL AUTHENTICATION SYSTEM (NO SUPABASE AUTH)
-- ============================================================================
-- Purpose: Replace Supabase Auth with custom table-based authentication
-- Use Case: Demo/Academic presentation - no email verification needed
-- ============================================================================

-- Drop existing auth-dependent policies first
DROP POLICY IF EXISTS "Users can view own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Public profiles viewable by authenticated users" ON public.users;

-- ============================================================================
-- 1. CUSTOM USERS TABLE (Manual Authentication)
-- ============================================================================

-- Drop and recreate users table with manual auth fields
DROP TABLE IF EXISTS public.users CASCADE;

CREATE TABLE public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Authentication Fields (NO Supabase Auth)
    -- ⚠️ WARNING: PLAINTEXT PASSWORD - FOR DEMO/ACADEMIC USE ONLY!
    username TEXT UNIQUE NOT NULL CHECK (length(username) >= 3),
    password TEXT NOT NULL, -- PLAINTEXT password (NO HASHING) for demo purposes
    
    -- Profile Fields
    full_name TEXT NOT NULL CHECK (length(full_name) >= 3),
    email TEXT, -- OPTIONAL - just a string, no validation
    phone_number TEXT,
    avatar_url TEXT,
    
    -- Role & Status
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    is_banned BOOLEAN DEFAULT FALSE,
    
    -- Location Fields
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address TEXT,
    city TEXT,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);

-- Add index for fast username lookup (for login)
CREATE UNIQUE INDEX idx_users_username ON public.users(username);
CREATE INDEX idx_users_email ON public.users(email);
CREATE INDEX idx_users_role ON public.users(role);

-- ============================================================================
-- 2. AUTO-UPDATE TIMESTAMP TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at ON public.users;
CREATE TRIGGER set_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Anyone can register (insert)
CREATE POLICY "Anyone can register"
    ON public.users
    FOR INSERT
    WITH CHECK (true);

-- Users can view their own profile
CREATE POLICY "Users can view own profile"
    ON public.users
    FOR SELECT
    USING (true); -- For simplicity, allow reading all profiles

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON public.users
    FOR UPDATE
    USING (id = (current_setting('app.current_user_id', true)::UUID))
    WITH CHECK (id = (current_setting('app.current_user_id', true)::UUID));

-- Admins can update any user
CREATE POLICY "Admins can update any user"
    ON public.users
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = (current_setting('app.current_user_id', true)::UUID)
            AND role = 'admin'
        )
    );

-- Admins can delete users
CREATE POLICY "Admins can delete users"
    ON public.users
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.users
            WHERE id = (current_setting('app.current_user_id', true)::UUID)
            AND role = 'admin'
        )
    );

-- ============================================================================
-- 4. AUTHENTICATION FUNCTIONS
-- ============================================================================

-- Drop old functions if they exist (to avoid signature conflicts)
DROP FUNCTION IF EXISTS public.register_user(TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.login_user(TEXT, TEXT);

-- Function to register new user
CREATE OR REPLACE FUNCTION public.register_user(
    p_username TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_email TEXT DEFAULT NULL,
    p_phone_number TEXT DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
    v_user_id UUID;
    v_result JSON;
BEGIN
    -- Check if username already exists
    IF EXISTS (SELECT 1 FROM public.users WHERE username = p_username) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Username sudah digunakan'
        );
    END IF;
    
    -- Check if email already exists (if provided)
    IF p_email IS NOT NULL AND p_email != '' THEN
        IF EXISTS (SELECT 1 FROM public.users WHERE email = p_email) THEN
            RETURN json_build_object(
                'success', false,
                'error', 'Email sudah terdaftar'
            );
        END IF;
    END IF;
    
    -- Insert new user (PLAINTEXT PASSWORD - DEMO ONLY!)
    INSERT INTO public.users (
        username,
        password,
        full_name,
        email,
        phone_number,
        role
    ) VALUES (
        p_username,
        p_password,
        p_full_name,
        NULLIF(p_email, ''),
        NULLIF(p_phone_number, ''),
        'user'
    ) RETURNING id INTO v_user_id;
    
    -- Return success with user data
    SELECT json_build_object(
        'success', true,
        'user', row_to_json(u.*)
    ) INTO v_result
    FROM public.users u
    WHERE u.id = v_user_id;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to login user
CREATE OR REPLACE FUNCTION public.login_user(
    p_username TEXT,
    p_password TEXT
) RETURNS JSON AS $$
DECLARE
    v_user_record RECORD;
    v_result JSON;
BEGIN
    -- Find user by username
    SELECT * INTO v_user_record
    FROM public.users
    WHERE username = p_username;
    
    -- User not found
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Username atau password salah'
        );
    END IF;
    
    -- Check if user is banned
    IF v_user_record.is_banned THEN
        RETURN json_build_object(
            'success', false,
            'error', 'ACCOUNT_BANNED'
        );
    END IF;
    
    -- Verify password (PLAINTEXT COMPARISON - DEMO ONLY!)
    IF v_user_record.password != p_password THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Username atau password salah'
        );
    END IF;
    
    -- Update last login time
    UPDATE public.users
    SET last_login_at = NOW()
    WHERE id = v_user_record.id;
    
    -- Return success with user data (excluding password)
    SELECT json_build_object(
        'success', true,
        'user', json_build_object(
            'id', v_user_record.id,
            'username', v_user_record.username,
            'full_name', v_user_record.full_name,
            'email', v_user_record.email,
            'phone_number', v_user_record.phone_number,
            'avatar_url', v_user_record.avatar_url,
            'role', v_user_record.role,
            'is_banned', v_user_record.is_banned,
            'latitude', v_user_record.latitude,
            'longitude', v_user_record.longitude,
            'address', v_user_record.address,
            'city', v_user_record.city,
            'created_at', v_user_record.created_at,
            'updated_at', v_user_record.updated_at,
            'last_login_at', NOW()
        )
    ) INTO v_result;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. CREATE DEMO ACCOUNTS
-- ============================================================================

-- ⚠️ PLAINTEXT PASSWORDS - FOR DEMO/ACADEMIC USE ONLY!
-- DO NOT USE IN PRODUCTION!

-- Insert demo admin user (username: admin, password: admin123)
INSERT INTO public.users (username, password, full_name, email, role)
VALUES ('admin', 'admin123', 'Administrator', 'admin@demo.com', 'admin')
ON CONFLICT (username) DO NOTHING;

-- Insert demo regular users (username: user1/user2, password: password123)
INSERT INTO public.users (username, password, full_name, email, role)
VALUES 
    ('user1', 'password123', 'Demo User 1', 'user1@demo.com', 'user'),
    ('user2', 'password123', 'Demo User 2', 'user2@demo.com', 'user'),
    ('demo', 'demo123', 'Demo Account', '', 'user')
ON CONFLICT (username) DO NOTHING;

-- ============================================================================
-- 6. UPDATE RELATED TABLES TO USE NEW USER ID
-- ============================================================================

-- Update products table foreign key
ALTER TABLE IF EXISTS public.products 
    DROP CONSTRAINT IF EXISTS products_owner_id_fkey;

ALTER TABLE IF EXISTS public.products
    ADD CONSTRAINT products_owner_id_fkey 
    FOREIGN KEY (owner_id) 
    REFERENCES public.users(id) 
    ON DELETE CASCADE;

-- Update bookings table foreign keys
ALTER TABLE IF EXISTS public.bookings
    DROP CONSTRAINT IF EXISTS bookings_renter_id_fkey;

ALTER TABLE IF EXISTS public.bookings
    ADD CONSTRAINT bookings_renter_id_fkey
    FOREIGN KEY (renter_id)
    REFERENCES public.users(id)
    ON DELETE CASCADE;

-- Update reports table foreign keys
ALTER TABLE IF EXISTS public.reports
    DROP CONSTRAINT IF EXISTS reports_reporter_id_fkey,
    DROP CONSTRAINT IF EXISTS reports_reported_user_id_fkey;

ALTER TABLE IF EXISTS public.reports
    ADD CONSTRAINT reports_reporter_id_fkey
    FOREIGN KEY (reporter_id)
    REFERENCES public.users(id)
    ON DELETE CASCADE,
    ADD CONSTRAINT reports_reported_user_id_fkey
    FOREIGN KEY (reported_user_id)
    REFERENCES public.users(id)
    ON DELETE CASCADE;

-- ============================================================================
-- 7. HELPER VIEWS
-- ============================================================================

-- View for public profiles (excluding sensitive data)
CREATE OR REPLACE VIEW public.public_profiles AS
SELECT 
    id,
    username,
    full_name,
    avatar_url,
    city,
    role,
    created_at
FROM public.users
WHERE is_banned = FALSE;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

COMMENT ON TABLE public.users IS 'Custom users table for manual authentication - NO Supabase Auth';
COMMENT ON FUNCTION public.register_user IS 'Register new user without Supabase Auth';
COMMENT ON FUNCTION public.login_user IS 'Login user with username/password validation';

-- Test the functions
SELECT public.register_user('testuser', 'test123', 'Test User', 'test@example.com', '081234567890');
SELECT public.login_user('testuser', 'test123');
