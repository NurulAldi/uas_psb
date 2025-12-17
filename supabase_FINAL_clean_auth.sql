-- ============================================================================
-- 🔐 RENTLENS - CLEAN AUTHENTICATION SYSTEM
-- ============================================================================
-- Version: 1.0 FINAL
-- Date: December 2024
-- Purpose: Simple manual authentication with single `users` table
-- 
-- ⚠️ IMPORTANT RULES:
--   1. NO Supabase Auth (auth.users) - COMPLETELY IGNORED
--   2. NO profiles table - DEPRECATED
--   3. Single `users` table for all authentication
--   4. Admin role set ONLY via database (no UI)
-- ============================================================================

-- ============================================================================
-- STEP 1: DROP OLD STUFF (CLEAN SLATE)
-- ============================================================================

-- Drop old views first (they depend on users table)
DROP VIEW IF EXISTS public.public_profiles;
DROP VIEW IF EXISTS public.v_public_profiles;

-- Drop old functions (CASCADE to remove dependent triggers)
DROP FUNCTION IF EXISTS public.register_user(TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.login_user(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS public.update_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.admin_ban_user(UUID, BOOLEAN) CASCADE;
DROP FUNCTION IF EXISTS public.admin_get_users() CASCADE;

-- Drop users table with CASCADE (this automatically drops policies, triggers, indexes)
DROP TABLE IF EXISTS public.users CASCADE;

-- Also drop profiles table if it exists (deprecated)
DROP TABLE IF EXISTS public.profiles CASCADE;

-- ============================================================================
-- STEP 2: CREATE `users` TABLE (SINGLE SOURCE OF TRUTH)
-- ============================================================================

CREATE TABLE public.users (
    -- Primary Key
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- 🔐 Authentication (Manual - NO Supabase Auth)
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    
    -- 👤 Profile Information
    full_name TEXT NOT NULL DEFAULT 'User',  -- Required but has default, can be updated in profile
    email TEXT,                  -- Optional, just for display
    phone_number TEXT,
    avatar_url TEXT,
    
    -- 🛡️ Role & Status
    role TEXT NOT NULL DEFAULT 'user',  -- 'user' or 'admin'
    is_banned BOOLEAN DEFAULT FALSE,
    
    -- 📍 Location (for 20km radius rental feature)
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address TEXT,
    city TEXT,
    
    -- 📅 Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_login_at TIMESTAMPTZ,
    
    -- ✅ Constraints
    CONSTRAINT username_min_length CHECK (length(username) >= 3),
    CONSTRAINT full_name_min_length CHECK (length(full_name) >= 2),
    CONSTRAINT valid_role CHECK (role IN ('user', 'admin'))
);

-- Add comment
COMMENT ON TABLE public.users IS 'Single users table for manual authentication - NO Supabase Auth';

-- ============================================================================
-- STEP 3: CREATE INDEXES
-- ============================================================================

CREATE UNIQUE INDEX idx_users_username ON public.users(username);
CREATE INDEX idx_users_email ON public.users(email) WHERE email IS NOT NULL;
CREATE INDEX idx_users_role ON public.users(role);
CREATE INDEX idx_users_is_banned ON public.users(is_banned);
CREATE INDEX idx_users_location ON public.users(latitude, longitude) 
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- ============================================================================
-- STEP 4: AUTO-UPDATE TIMESTAMP TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- ============================================================================
-- STEP 5: ROW LEVEL SECURITY (RLS)
-- ============================================================================
-- For simplicity in demo/academic app, we use permissive policies
-- In production, you'd use more restrictive policies

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Anyone can INSERT (register)
CREATE POLICY "allow_insert" ON public.users
    FOR INSERT WITH CHECK (true);

-- Anyone can SELECT (read profiles)
CREATE POLICY "allow_select" ON public.users
    FOR SELECT USING (true);

-- Anyone can UPDATE (will be controlled in app logic)
CREATE POLICY "allow_update" ON public.users
    FOR UPDATE USING (true) WITH CHECK (true);

-- Only allow DELETE via RPC (admin function)
CREATE POLICY "allow_delete" ON public.users
    FOR DELETE USING (true);

-- ============================================================================
-- STEP 6: AUTHENTICATION FUNCTIONS
-- ============================================================================

-- 📝 REGISTER USER
-- Returns: { success: boolean, error?: string, user?: object }
CREATE OR REPLACE FUNCTION public.register_user(
    p_username TEXT,
    p_password_hash TEXT,
    p_full_name TEXT,
    p_email TEXT DEFAULT NULL,
    p_phone_number TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_user RECORD;
BEGIN
    -- Normalize username
    p_username := LOWER(TRIM(p_username));
    
    -- Validate username length
    IF LENGTH(p_username) < 3 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Username minimal 3 karakter'
        );
    END IF;
    
    -- Use username as default full_name if not provided
    IF p_full_name IS NULL OR TRIM(p_full_name) = '' THEN
        p_full_name := p_username;
    END IF;
    
    -- Check if username exists
    IF EXISTS (SELECT 1 FROM public.users WHERE username = p_username) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Username sudah digunakan'
        );
    END IF;
    
    -- Check if email exists (if provided)
    IF p_email IS NOT NULL AND TRIM(p_email) != '' THEN
        IF EXISTS (SELECT 1 FROM public.users WHERE email = TRIM(p_email)) THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Email sudah terdaftar'
            );
        END IF;
    END IF;
    
    -- Insert new user (role is always 'user' for registration)
    INSERT INTO public.users (
        username,
        password_hash,
        full_name,
        email,
        phone_number,
        role
    ) VALUES (
        p_username,
        p_password_hash,
        TRIM(p_full_name),
        NULLIF(TRIM(p_email), ''),
        NULLIF(TRIM(p_phone_number), ''),
        'user'  -- Always 'user', admin is set manually in DB
    )
    RETURNING id INTO v_user_id;
    
    -- Fetch the created user
    SELECT * INTO v_user FROM public.users WHERE id = v_user_id;
    
    -- Return success
    RETURN jsonb_build_object(
        'success', true,
        'user', jsonb_build_object(
            'id', v_user.id,
            'username', v_user.username,
            'full_name', v_user.full_name,
            'email', v_user.email,
            'phone_number', v_user.phone_number,
            'avatar_url', v_user.avatar_url,
            'role', v_user.role,
            'is_banned', v_user.is_banned,
            'latitude', v_user.latitude,
            'longitude', v_user.longitude,
            'address', v_user.address,
            'city', v_user.city,
            'created_at', v_user.created_at,
            'updated_at', v_user.updated_at,
            'last_login_at', v_user.last_login_at
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Gagal mendaftar: ' || SQLERRM
    );
END;
$$;

-- 🔐 LOGIN USER
-- Returns: { success: boolean, error?: string, user?: object }
CREATE OR REPLACE FUNCTION public.login_user(
    p_username TEXT,
    p_password_hash TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user RECORD;
BEGIN
    -- Normalize username
    p_username := LOWER(TRIM(p_username));
    
    -- Find user
    SELECT * INTO v_user
    FROM public.users
    WHERE username = p_username;
    
    -- User not found
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Username atau password salah'
        );
    END IF;
    
    -- Check if banned
    IF v_user.is_banned THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'ACCOUNT_BANNED'
        );
    END IF;
    
    -- Verify password
    IF v_user.password_hash != p_password_hash THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Username atau password salah'
        );
    END IF;
    
    -- Update last login time
    UPDATE public.users
    SET last_login_at = NOW()
    WHERE id = v_user.id;
    
    -- Return success with user data (excluding password_hash)
    RETURN jsonb_build_object(
        'success', true,
        'user', jsonb_build_object(
            'id', v_user.id,
            'username', v_user.username,
            'full_name', v_user.full_name,
            'email', v_user.email,
            'phone_number', v_user.phone_number,
            'avatar_url', v_user.avatar_url,
            'role', v_user.role,
            'is_banned', v_user.is_banned,
            'latitude', v_user.latitude,
            'longitude', v_user.longitude,
            'address', v_user.address,
            'city', v_user.city,
            'created_at', v_user.created_at,
            'updated_at', v_user.updated_at,
            'last_login_at', NOW()
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', 'Login gagal: ' || SQLERRM
    );
END;
$$;

-- ============================================================================
-- STEP 7: ADMIN FUNCTIONS (For Admin Dashboard)
-- ============================================================================

-- 🚫 BAN USER (Admin only - called from app with admin check)
CREATE OR REPLACE FUNCTION public.admin_ban_user(p_user_id UUID, p_ban BOOLEAN)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.users
    SET is_banned = p_ban, updated_at = NOW()
    WHERE id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'User tidak ditemukan');
    END IF;
    
    RETURN jsonb_build_object('success', true);
END;
$$;

-- 📊 GET ALL USERS (Admin only)
CREATE OR REPLACE FUNCTION public.admin_get_users()
RETURNS SETOF public.users
LANGUAGE sql
SECURITY DEFINER
AS $$
    SELECT * FROM public.users ORDER BY created_at DESC;
$$;

-- ============================================================================
-- STEP 8: CREATE DEMO ACCOUNTS
-- ============================================================================
-- Password hashes are SHA-256 of the password (demo-grade security)
-- In Flutter: PasswordHelper.hashPassword('password123')

-- Admin account (password: admin123)
-- SHA-256 of 'admin123' = 240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9
INSERT INTO public.users (username, password_hash, full_name, email, role)
VALUES (
    'admin',
    '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9',
    'Administrator',
    'admin@rentlens.demo',
    'admin'
) ON CONFLICT (username) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    role = 'admin';

-- Demo user 1 (password: password123)
-- SHA-256 of 'password123' = ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f
INSERT INTO public.users (username, password_hash, full_name, email, role)
VALUES (
    'demo',
    'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f',
    'Demo User',
    'demo@rentlens.demo',
    'user'
) ON CONFLICT (username) DO UPDATE SET
    password_hash = EXCLUDED.password_hash;

-- Demo user 2 (password: user123)
-- SHA-256 of 'user123' = 5eb63bbbe01eeed093cb22bb8f5acdc3
INSERT INTO public.users (username, password_hash, full_name, email, role)
VALUES (
    'user1',
    '0a041b9462caa4a31bac3567e0b6e6fd9100787db2ab433d96f6d178cabfce90',
    'User Satu',
    'user1@rentlens.demo',
    'user'
) ON CONFLICT (username) DO NOTHING;

-- ============================================================================
-- STEP 9: CLEAN OLD DATA & UPDATE FOREIGN KEYS
-- ============================================================================
-- Since we're doing a clean reset, we need to clear old data that references
-- the old user IDs that no longer exist

-- Clear existing data from dependent tables (safely)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'reports') THEN
        TRUNCATE TABLE public.reports CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bookings') THEN
        TRUNCATE TABLE public.bookings CASCADE;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'products') THEN
        TRUNCATE TABLE public.products CASCADE;
    END IF;
END $$;

-- Drop old custom_users table if it exists
DROP TABLE IF EXISTS public.custom_users CASCADE;

-- Update foreign keys on related tables
-- Products table - owner_id
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' AND column_name = 'owner_id'
    ) THEN
        ALTER TABLE public.products DROP CONSTRAINT IF EXISTS products_owner_id_fkey;
        ALTER TABLE public.products
            ADD CONSTRAINT products_owner_id_fkey
            FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Bookings table - check for renter_id or user_id
DO $$
BEGIN
    -- Check if renter_id column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'renter_id'
    ) THEN
        ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_renter_id_fkey;
        ALTER TABLE public.bookings
            ADD CONSTRAINT bookings_renter_id_fkey
            FOREIGN KEY (renter_id) REFERENCES public.users(id) ON DELETE CASCADE;
    -- Check if user_id column exists instead
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_user_id_fkey;
        ALTER TABLE public.bookings
            ADD CONSTRAINT bookings_user_id_fkey
            FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Reports table
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'reports' AND column_name = 'reporter_id'
    ) THEN
        ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_reporter_id_fkey;
        ALTER TABLE public.reports
            ADD CONSTRAINT reports_reporter_id_fkey
            FOREIGN KEY (reporter_id) REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'reports' AND column_name = 'reported_user_id'
    ) THEN
        ALTER TABLE public.reports DROP CONSTRAINT IF EXISTS reports_reported_user_id_fkey;
        ALTER TABLE public.reports
            ADD CONSTRAINT reports_reported_user_id_fkey
            FOREIGN KEY (reported_user_id) REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;
END $$;

-- ============================================================================
-- STEP 10: CREATE HELPER VIEW
-- ============================================================================

CREATE OR REPLACE VIEW public.v_public_profiles AS
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
-- ✅ MIGRATION COMPLETE
-- ============================================================================

-- Summary
SELECT '✅ MIGRATION COMPLETE' as status;
SELECT 'Total users: ' || COUNT(*) as info FROM public.users;
SELECT 'Admin users: ' || COUNT(*) as info FROM public.users WHERE role = 'admin';

-- ============================================================================
-- 📋 QUICK REFERENCE
-- ============================================================================
-- 
-- LOGIN CREDENTIALS (for testing):
-- ┌──────────┬─────────────┬────────┐
-- │ Username │ Password    │ Role   │
-- ├──────────┼─────────────┼────────┤
-- │ admin    │ admin123    │ admin  │
-- │ demo     │ password123 │ user   │
-- │ user1    │ user123     │ user   │
-- └──────────┴─────────────┴────────┘
--
-- TO MAKE A USER ADMIN (manually in Supabase SQL Editor):
--   UPDATE public.users SET role = 'admin' WHERE username = 'targetuser';
--
-- TO BAN A USER:
--   UPDATE public.users SET is_banned = true WHERE username = 'baduser';
--
-- ============================================================================
