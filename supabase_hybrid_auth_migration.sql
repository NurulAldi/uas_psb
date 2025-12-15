-- =====================================================
-- HYBRID AUTHENTICATION SYSTEM MIGRATION
-- Supabase-Compatible SQL Migration Script
-- =====================================================
-- Description: Enables custom user management alongside existing Supabase Auth
-- Version: 2.0 (Supabase-Compatible)
-- Date: 2024-12-15
-- Tested: Supabase PostgreSQL 15+
-- =====================================================
-- CRITICAL: This maintains FULL backward compatibility with existing auth users
-- =====================================================

-- =====================================================
-- STEP 0: ENABLE REQUIRED EXTENSIONS
-- =====================================================
-- pgcrypto for password hashing (available in Supabase)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- PostGIS for location features (optional, but recommended)
CREATE EXTENSION IF NOT EXISTS postgis;

-- =====================================================
-- STEP 1: CREATE CUSTOM USERS TABLE
-- =====================================================
-- This table stores manually-managed users (no Supabase Auth required)

CREATE TABLE IF NOT EXISTS custom_users (
  -- Primary key (not tied to auth.users)
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Authentication credentials (manual management)
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL, -- Store bcrypt/argon2 hash, NEVER plain text
  
  -- User information (mirrors profiles structure)
  email TEXT, -- Optional for custom users (no validation required)
  full_name TEXT,
  phone_number TEXT,
  avatar_url TEXT,
  
  -- Role and status (same as profiles)
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  is_banned BOOLEAN DEFAULT false,
  
  -- Location fields (for 20km rental feature)
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  address TEXT,
  city TEXT,
  location_updated_at TIMESTAMPTZ,
  
  -- Authentication metadata
  last_login_at TIMESTAMPTZ,
  login_attempts INTEGER DEFAULT 0,
  locked_until TIMESTAMPTZ, -- Account lockout for security
  
  -- Standard timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT username_length CHECK (LENGTH(username) >= 3),
  CONSTRAINT username_format CHECK (username ~ '^[a-zA-Z0-9_]+$') -- Alphanumeric + underscore only
);

-- =====================================================
-- STEP 2: CREATE INDEXES FOR PERFORMANCE
-- =====================================================

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_custom_users_username ON custom_users(username);
CREATE INDEX IF NOT EXISTS idx_custom_users_email ON custom_users(email) WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_custom_users_role ON custom_users(role);
CREATE INDEX IF NOT EXISTS idx_custom_users_is_banned ON custom_users(is_banned) WHERE is_banned = true;

-- Geospatial indexes (Supabase-compatible approach)
-- Option A: PostGIS geography column (RECOMMENDED)
DO $$ 
BEGIN
  -- Add geography point column if PostGIS is available
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'custom_users' AND column_name = 'location_point'
  ) THEN
    ALTER TABLE custom_users ADD COLUMN location_point geography(POINT, 4326);
  END IF;
  
  -- Populate geography column from lat/lon
  UPDATE custom_users 
  SET location_point = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
  WHERE latitude IS NOT NULL 
    AND longitude IS NOT NULL 
    AND location_point IS NULL;
    
EXCEPTION 
  WHEN undefined_function THEN
    RAISE NOTICE 'PostGIS not available, using fallback indexes';
END $$;

-- Create spatial index (PostGIS)
CREATE INDEX IF NOT EXISTS idx_custom_users_location_geography
ON custom_users USING gist(location_point)
WHERE location_point IS NOT NULL;

-- Option B: Fallback B-tree indexes (works without PostGIS)
CREATE INDEX IF NOT EXISTS idx_custom_users_latitude 
ON custom_users(latitude)
WHERE latitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_custom_users_longitude 
ON custom_users(longitude)
WHERE longitude IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_custom_users_lat_lon_composite
ON custom_users(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- =====================================================
-- STEP 3: ADD AUTH_TYPE COLUMN TO PROFILES TABLE
-- =====================================================
-- Mark existing Supabase Auth users for hybrid authentication

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS auth_type TEXT DEFAULT 'supabase_auth' 
CHECK (auth_type IN ('supabase_auth', 'custom'));

CREATE INDEX IF NOT EXISTS idx_profiles_auth_type ON profiles(auth_type);

-- =====================================================
-- STEP 4: CREATE UNIFIED VIEW FOR ALL USERS
-- =====================================================
-- This view combines both Supabase Auth users and custom users

CREATE OR REPLACE VIEW all_users AS
-- Supabase Auth users from profiles table
SELECT 
  id,
  email,
  full_name,
  phone_number,
  avatar_url,
  role,
  is_banned,
  latitude,
  longitude,
  address,
  city,
  location_updated_at,
  created_at,
  updated_at,
  'supabase_auth' AS auth_type,
  NULL::TEXT AS username,
  NULL::TIMESTAMPTZ AS last_login_at
FROM profiles
WHERE auth_type = 'supabase_auth'

UNION ALL

-- Custom users from custom_users table
SELECT 
  id,
  email,
  full_name,
  phone_number,
  avatar_url,
  role,
  is_banned,
  latitude,
  longitude,
  address,
  city,
  location_updated_at,
  created_at,
  updated_at,
  'custom' AS auth_type,
  username,
  last_login_at
FROM custom_users;

-- =====================================================
-- STEP 5: CREATE TRIGGER FOR UPDATED_AT
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_custom_users_updated_at ON custom_users;

CREATE TRIGGER update_custom_users_updated_at
  BEFORE UPDATE ON custom_users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- STEP 6: ROW LEVEL SECURITY (RLS) FOR CUSTOM_USERS
-- =====================================================
-- IMPORTANT: Supabase RLS policies must be carefully designed
-- auth.uid() may return NULL for custom users (they're not in auth.users)
-- We'll use a combination of application-level session management and RLS

ALTER TABLE custom_users ENABLE ROW LEVEL SECURITY;

-- Policy 1: Public read access for authentication purposes
-- This allows the login endpoint to verify credentials
CREATE POLICY "Public read access for authentication"
  ON custom_users FOR SELECT
  USING (true);

-- Policy 2: Users can update their own profile (via application session)
-- NOTE: Since custom users aren't in auth.users, we can't use auth.uid()
-- The application must implement its own session management
-- This policy allows updates if the application sets a custom claim
CREATE POLICY "Users can update own profile"
  ON custom_users FOR UPDATE
  USING (
    -- Allow if current user is the profile owner (via application claim)
    id = (current_setting('app.current_user_id', true))::uuid
  )
  WITH CHECK (
    -- Prevent modification of sensitive fields
    -- Check that username hasn't changed
    username = (SELECT username FROM custom_users WHERE id = (current_setting('app.current_user_id', true))::uuid)
    -- Check that password_hash hasn't changed (password updates should use dedicated function)
    AND password_hash = (SELECT password_hash FROM custom_users WHERE id = (current_setting('app.current_user_id', true))::uuid)
    -- Check that role hasn't changed
    AND role = (SELECT role FROM custom_users WHERE id = (current_setting('app.current_user_id', true))::uuid)
    -- Check that is_banned hasn't changed
    AND is_banned = (SELECT is_banned FROM custom_users WHERE id = (current_setting('app.current_user_id', true))::uuid)
  );

-- Policy 3: Admin access (works for both Supabase Auth admins and custom admins)
CREATE POLICY "Admin full access"
  ON custom_users FOR ALL
  USING (
    -- Check if Supabase Auth user is admin
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
    OR
    -- Check if custom user is admin (via application claim)
    EXISTS (
      SELECT 1 FROM custom_users 
      WHERE id = (current_setting('app.current_user_id', true))::uuid 
        AND role = 'admin'
    )
  );

-- Policy 4: Allow registration (public insert)
CREATE POLICY "Allow user registration"
  ON custom_users FOR INSERT
  WITH CHECK (
    -- Only allow user role on registration (not admin)
    role = 'user'
    AND is_banned = false
  );

-- =====================================================
-- STEP 7: HELPER FUNCTIONS FOR AUTHENTICATION
-- =====================================================

-- Function: Check if username exists
CREATE OR REPLACE FUNCTION username_exists(p_username TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM custom_users WHERE username = p_username
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Check if custom user is banned
CREATE OR REPLACE FUNCTION is_custom_user_banned(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  v_is_banned BOOLEAN;
BEGIN
  SELECT is_banned INTO v_is_banned
  FROM custom_users
  WHERE id = p_user_id;
  
  RETURN COALESCE(v_is_banned, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Update last login timestamp
CREATE OR REPLACE FUNCTION update_custom_user_login(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE custom_users
  SET 
    last_login_at = NOW(),
    login_attempts = 0,
    locked_until = NULL
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Increment login attempts (for security)
CREATE OR REPLACE FUNCTION increment_login_attempts(p_username TEXT)
RETURNS INTEGER AS $$
DECLARE
  v_attempts INTEGER;
BEGIN
  UPDATE custom_users
  SET 
    login_attempts = login_attempts + 1,
    locked_until = CASE 
      WHEN login_attempts + 1 >= 5 THEN NOW() + INTERVAL '15 minutes'
      ELSE locked_until
    END
  WHERE username = p_username
  RETURNING login_attempts INTO v_attempts;
  
  RETURN COALESCE(v_attempts, 0);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get user by username (for login validation)
CREATE OR REPLACE FUNCTION get_custom_user_by_username(p_username TEXT)
RETURNS TABLE (
  id UUID,
  username TEXT,
  password_hash TEXT,
  is_banned BOOLEAN,
  locked_until TIMESTAMPTZ,
  login_attempts INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    cu.id,
    cu.username,
    cu.password_hash,
    cu.is_banned,
    cu.locked_until,
    cu.login_attempts
  FROM custom_users cu
  WHERE cu.username = p_username;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Set session for custom user (required for RLS)
CREATE OR REPLACE FUNCTION set_custom_user_session(user_id UUID)
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('app.current_user_id', user_id::text, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Clear session
CREATE OR REPLACE FUNCTION clear_custom_user_session()
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('app.current_user_id', '', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- STEP 8: UPDATE EXISTING TABLES TO SUPPORT HYBRID AUTH
-- =====================================================

-- Update bookings table to accept both auth types
-- (Already supports UUID foreign keys, so no changes needed)

-- Update reports table to accept both auth types
-- (Already supports UUID foreign keys, so no changes needed)

-- =====================================================
-- STEP 9: CREATE TRIGGER FOR LOCATION_POINT (CUSTOM_USERS)
-- =====================================================

CREATE OR REPLACE FUNCTION update_custom_users_location_point()
RETURNS TRIGGER AS $$
BEGIN
  BEGIN
    IF NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
      NEW.location_point := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography;
    ELSE
      NEW.location_point := NULL;
    END IF;
  EXCEPTION
    WHEN undefined_function THEN
      -- PostGIS not available, skip
      NULL;
  END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_custom_users_location_point ON custom_users;

CREATE TRIGGER trigger_update_custom_users_location_point
  BEFORE INSERT OR UPDATE OF latitude, longitude ON custom_users
  FOR EACH ROW
  EXECUTE FUNCTION update_custom_users_location_point();

-- =====================================================
-- STEP 10: MIGRATION SAFEGUARDS
-- =====================================================

-- Ensure all existing profiles are marked as 'supabase_auth'
UPDATE profiles
SET auth_type = 'supabase_auth'
WHERE auth_type IS NULL;

-- =====================================================
-- VERIFICATION QUERIES (Run after migration)
-- =====================================================

-- Verify all existing users are preserved
-- SELECT COUNT(*) as supabase_auth_users FROM profiles WHERE auth_type = 'supabase_auth';
-- SELECT COUNT(*) as custom_users FROM custom_users;
-- SELECT * FROM all_users ORDER BY created_at DESC LIMIT 10;

-- =====================================================
-- NOTES FOR DEVELOPERS
-- =====================================================
-- 1. Existing Supabase Auth flow remains UNCHANGED
--    - auth.users table is still used
--    - profiles table foreign key to auth.users(id) is preserved
--    - All existing RLS policies continue to work
--
-- 2. New Custom Auth flow:
--    - Users are stored in custom_users table
--    - Authentication is handled in Flutter application layer
--    - Password hashing MUST be done server-side or in Flutter
--    - Use bcrypt or argon2 for password hashing
--
-- 3. Unified View:
--    - Use 'all_users' view to query all users regardless of auth type
--    - Check 'auth_type' column to determine authentication method
--
-- 4. Session Management:
--    - Supabase Auth users: Use existing Supabase session (JWT)
--    - Custom users: Implement custom session tokens or use Supabase session with custom claims
--
-- 5. Security Considerations:
--    - NEVER store plain text passwords
--    - Always hash passwords with bcrypt (cost factor 12+) or argon2
--    - Implement rate limiting for login attempts
--    - Use HTTPS for all authentication requests
--    - Consider implementing 2FA for sensitive operations
--
-- 6. Migration Path for Existing Users:
--    - Existing users continue using Supabase Auth (zero changes)
--    - New registrations can choose between Supabase Auth or Custom Auth
--    - Users CANNOT migrate between auth types (by design, for security)

-- =====================================================
-- END OF MIGRATION
-- =====================================================
