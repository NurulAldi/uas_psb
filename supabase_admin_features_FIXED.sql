-- =====================================================
-- ADMIN FEATURES MIGRATION (FIXED VERSION)
-- =====================================================
-- Purpose: Add admin and reporting features
-- Fixed: Uses 'profiles' table instead of 'users'
-- Uses role-based admin instead of separate table
-- =====================================================

-- =====================================================
-- 1. ADD ADMIN & BAN COLUMNS TO PROFILES
-- =====================================================

-- Add role column for admin/user distinction
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user' 
  CHECK (role IN ('user', 'admin'));

-- Add is_banned column to track banned users
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE;

-- Add banned_at column to track when user was banned
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS banned_at TIMESTAMPTZ;

-- Add banned_by column to track which admin banned the user
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS banned_by UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- Add ban_reason column
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS ban_reason TEXT;

-- Add indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_is_banned ON profiles(is_banned);

COMMENT ON COLUMN profiles.role IS 'User role: user or admin';
COMMENT ON COLUMN profiles.is_banned IS 'Whether user is banned from the platform';
COMMENT ON COLUMN profiles.banned_at IS 'Timestamp when user was banned';
COMMENT ON COLUMN profiles.banned_by IS 'Admin who banned this user';
COMMENT ON COLUMN profiles.ban_reason IS 'Reason for banning the user';

-- =====================================================
-- 2. CREATE REPORTS TABLE (USER REPORTS ONLY)
-- =====================================================

-- Create enum type for report status
DO $$ BEGIN
    CREATE TYPE report_status AS ENUM ('pending', 'reviewed', 'resolved', 'rejected');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create reports table (for reporting users only)
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reported_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    description TEXT,
    status report_status DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Prevent self-reporting
    CONSTRAINT check_not_self_report CHECK (reporter_id != reported_user_id)
);

-- Add indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_reports_reporter ON reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_user ON reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);

COMMENT ON TABLE reports IS 'User reports for reporting problematic users';
COMMENT ON COLUMN reports.reporter_id IS 'User who submitted the report';
COMMENT ON COLUMN reports.reported_user_id IS 'User being reported';

-- =====================================================
-- 3. RLS POLICIES FOR REPORTS
-- =====================================================

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Users can create reports
DROP POLICY IF EXISTS "Users can create reports" ON reports;
CREATE POLICY "Users can create reports"
    ON reports
    FOR INSERT
    WITH CHECK (auth.uid() = reporter_id);

-- Users can view their own reports
DROP POLICY IF EXISTS "Users can view their own reports" ON reports;
CREATE POLICY "Users can view their own reports"
    ON reports
    FOR SELECT
    USING (auth.uid() = reporter_id);

-- Admins can view all reports
DROP POLICY IF EXISTS "Admins can view all reports" ON reports;
CREATE POLICY "Admins can view all reports"
    ON reports
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Admins can update reports
DROP POLICY IF EXISTS "Admins can update reports" ON reports;
CREATE POLICY "Admins can update reports"
    ON reports
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- =====================================================
-- 4. UPDATE RLS POLICIES FOR BANNED USERS
-- =====================================================

-- Prevent banned users from creating products
DROP POLICY IF EXISTS "Banned users cannot create products" ON products;
CREATE POLICY "Banned users cannot create products"
    ON products
    FOR INSERT
    WITH CHECK (
        NOT EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND is_banned = TRUE
        )
    );

-- Prevent banned users from updating products
DROP POLICY IF EXISTS "Banned users cannot update products" ON products;
CREATE POLICY "Banned users cannot update products"
    ON products
    FOR UPDATE
    USING (
        NOT EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND is_banned = TRUE
        )
    );

-- Prevent banned users from creating bookings
DROP POLICY IF EXISTS "Banned users cannot create bookings" ON bookings;
CREATE POLICY "Banned users cannot create bookings"
    ON bookings
    FOR INSERT
    WITH CHECK (
        NOT EXISTS (
            SELECT 1 FROM profiles
            WHERE id = auth.uid() AND is_banned = TRUE
        )
    );

-- =====================================================
-- 5. FUNCTIONS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for reports table
DROP TRIGGER IF EXISTS update_reports_updated_at ON reports;
CREATE TRIGGER update_reports_updated_at
    BEFORE UPDATE ON reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to ban user (for admin use)
DROP FUNCTION IF EXISTS ban_user CASCADE;
CREATE FUNCTION ban_user(
    user_id_param UUID,
    reason_param TEXT,
    admin_id_param UUID
)
RETURNS VOID AS $$
BEGIN
    -- Check if admin
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = admin_id_param AND role = 'admin') THEN
        RAISE EXCEPTION 'Only admins can ban users';
    END IF;
    
    -- Ban the user
    UPDATE profiles
    SET 
        is_banned = TRUE,
        banned_at = NOW(),
        banned_by = admin_id_param,
        ban_reason = reason_param
    WHERE id = user_id_param;
    
    -- Set all user's products to unavailable
    UPDATE products
    SET is_available = FALSE
    WHERE owner_id = user_id_param;
    
    RAISE NOTICE 'User % has been banned by admin %', user_id_param, admin_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION ban_user IS 'Ban a user and make their products unavailable';

-- Function to unban user (for admin use)
DROP FUNCTION IF EXISTS unban_user CASCADE;
CREATE FUNCTION unban_user(
    user_id_param UUID,
    admin_id_param UUID
)
RETURNS VOID AS $$
BEGIN
    -- Check if admin
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = admin_id_param AND role = 'admin') THEN
        RAISE EXCEPTION 'Only admins can unban users';
    END IF;
    
    -- Unban the user
    UPDATE profiles
    SET 
        is_banned = FALSE,
        banned_at = NULL,
        banned_by = NULL,
        ban_reason = NULL
    WHERE id = user_id_param;
    
    RAISE NOTICE 'User % has been unbanned by admin %', user_id_param, admin_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION unban_user IS 'Unban a previously banned user';

-- =====================================================
-- 6. VIEWS FOR ADMIN DASHBOARD
-- =====================================================

-- View for reports with related data
CREATE OR REPLACE VIEW admin_reports_view AS
SELECT 
    r.id,
    r.reason,
    r.status,
    r.created_at,
    r.updated_at,
    
    -- Reporter info
    reporter.id AS reporter_id,
    reporter.full_name AS reporter_name,
    reporter.email AS reporter_email,
    reporter.phone_number AS reporter_phone,
    
    -- Reported user info
    reported_user.id AS reported_user_id,
    reported_user.full_name AS reported_user_name,
    reported_user.email AS reported_user_email,
    reported_user.phone_number AS reported_user_phone,
    reported_user.is_banned AS reported_user_is_banned
    
FROM reports r
INNER JOIN profiles reporter ON r.reporter_id = reporter.id
INNER JOIN profiles reported_user ON r.reported_user_id = reported_user.id;

COMMENT ON VIEW admin_reports_view IS 'Complete user report information for admin dashboard';

-- View for banned users
CREATE OR REPLACE VIEW admin_banned_users_view AS
SELECT 
    u.id,
    u.email,
    u.full_name,
    u.phone_number,
    u.is_banned,
    u.banned_at,
    u.ban_reason,
    
    -- Banned by admin info
    a.full_name AS banned_by_name,
    a.email AS banned_by_email,
    
    -- Count user's products
    (SELECT COUNT(*) FROM products WHERE owner_id = u.id) AS products_count,
    
    -- Count user's bookings (as renter)
    (SELECT COUNT(*) FROM bookings WHERE user_id = u.id) AS bookings_count,
    
    -- Count reports against this user
    (SELECT COUNT(*) FROM reports WHERE reported_user_id = u.id) AS reports_count
    
FROM profiles u
LEFT JOIN profiles a ON u.banned_by = a.id
WHERE u.is_banned = TRUE
ORDER BY u.banned_at DESC;

COMMENT ON VIEW admin_banned_users_view IS 'List of banned users with statistics';

-- View for admin statistics
CREATE OR REPLACE VIEW admin_stats_view AS
SELECT
    -- User stats
    (SELECT COUNT(*) FROM profiles) AS total_users,
    (SELECT COUNT(*) FROM profiles WHERE role = 'admin') AS total_admins,
    (SELECT COUNT(*) FROM profiles WHERE is_banned = TRUE) AS total_banned,
    (SELECT COUNT(*) FROM profiles WHERE created_at > NOW() - INTERVAL '30 days') AS new_users_30d,
    
    -- Product stats
    (SELECT COUNT(*) FROM products) AS total_products,
    (SELECT COUNT(*) FROM products WHERE is_available = TRUE) AS available_products,
    (SELECT COUNT(*) FROM products WHERE created_at > NOW() - INTERVAL '30 days') AS new_products_30d,
    
    -- Booking stats
    (SELECT COUNT(*) FROM bookings) AS total_bookings,
    (SELECT COUNT(*) FROM bookings WHERE status = 'pending') AS pending_bookings,
    (SELECT COUNT(*) FROM bookings WHERE status = 'active') AS active_bookings,
    (SELECT COUNT(*) FROM bookings WHERE created_at > NOW() - INTERVAL '30 days') AS new_bookings_30d,
    
    -- Report stats
    (SELECT COUNT(*) FROM reports) AS total_reports,
    (SELECT COUNT(*) FROM reports WHERE status = 'pending') AS pending_reports,
    (SELECT COUNT(*) FROM reports WHERE status = 'resolved') AS resolved_reports,
    (SELECT COUNT(*) FROM reports WHERE created_at > NOW() - INTERVAL '30 days') AS new_reports_30d;

COMMENT ON VIEW admin_stats_view IS 'Dashboard statistics for admin';

-- Grant access to views for admins only
-- Note: RLS on underlying tables will still apply
GRANT SELECT ON admin_reports_view TO authenticated;
GRANT SELECT ON admin_banned_users_view TO authenticated;
GRANT SELECT ON admin_stats_view TO authenticated;

-- =====================================================
-- 7. CREATE FIRST ADMIN USER (OPTIONAL)
-- =====================================================

-- Update existing user to admin, or wait for manual promotion
-- Example: Promote user by email
-- UPDATE profiles SET role = 'admin' WHERE email = 'admin@rentlens.com';

COMMENT ON COLUMN profiles.role IS 'To create admin: UPDATE profiles SET role = ''admin'' WHERE email = ''your-email@example.com''';

-- =====================================================
-- 8. VERIFICATION QUERIES
-- =====================================================

-- Check if columns exist
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'profiles' 
-- AND column_name IN ('role', 'is_banned', 'banned_at', 'banned_by', 'ban_reason');

-- Check if reports table exists
-- SELECT * FROM reports LIMIT 1;

-- Check admin users
-- SELECT id, email, full_name, role FROM profiles WHERE role = 'admin';

-- Check banned users
-- SELECT * FROM admin_banned_users_view;

-- Check statistics
-- SELECT * FROM admin_stats_view;

-- =====================================================
-- END OF MIGRATION
-- =====================================================
