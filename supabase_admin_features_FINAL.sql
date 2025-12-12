-- =====================================================
-- ADMIN FEATURES MIGRATION (FINAL VERSION)
-- =====================================================
-- Purpose: Add complete admin and reporting features
-- Fixed: All table references, handles existing tables
-- Compatible: Works with or without previous RBAC migration
-- =====================================================

-- =====================================================
-- 1. ADD ADMIN & BAN COLUMNS TO PROFILES
-- =====================================================

-- Add role column for admin/user distinction
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user';

-- Add check constraint if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'profiles_role_check'
  ) THEN
    ALTER TABLE profiles 
    ADD CONSTRAINT profiles_role_check 
    CHECK (role IN ('user', 'admin'));
  END IF;
END $$;

-- Add is_banned column to track banned users
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE;

-- Add banned_at column to track when user was banned
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS banned_at TIMESTAMPTZ;

-- Add banned_by column to track which admin banned the user
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS banned_by UUID;

-- Add foreign key constraint if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'profiles_banned_by_fkey'
  ) THEN
    ALTER TABLE profiles 
    ADD CONSTRAINT profiles_banned_by_fkey 
    FOREIGN KEY (banned_by) REFERENCES profiles(id) ON DELETE SET NULL;
  END IF;
END $$;

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
-- 2. HANDLE EXISTING REPORTS TABLE
-- =====================================================

-- Check if reports table exists and has old structure
DO $$
DECLARE
  has_report_type BOOLEAN;
  has_reported_product_id BOOLEAN;
BEGIN
  -- Check if table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'reports') THEN
    -- Check if report_type column exists
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'reports' AND column_name = 'report_type'
    ) INTO has_report_type;
    
    -- Check if reported_product_id column exists
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_name = 'reports' AND column_name = 'reported_product_id'
    ) INTO has_reported_product_id;
    
    -- If old structure (from rbac script), migrate it
    IF NOT has_report_type AND NOT has_reported_product_id THEN
      RAISE NOTICE 'Migrating old reports table structure to new version...';
      
      -- Add new columns
      ALTER TABLE reports 
      ADD COLUMN IF NOT EXISTS report_type TEXT DEFAULT 'user';
      
      ALTER TABLE reports 
      ADD COLUMN IF NOT EXISTS reported_product_id UUID;
      
      -- Add foreign key
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'reports_reported_product_id_fkey'
      ) THEN
        ALTER TABLE reports 
        ADD CONSTRAINT reports_reported_product_id_fkey 
        FOREIGN KEY (reported_product_id) REFERENCES products(id) ON DELETE CASCADE;
      END IF;
      
      -- Add description column if not exists
      ALTER TABLE reports 
      ADD COLUMN IF NOT EXISTS description TEXT;
      
      -- Update status values if needed
      -- Old: 'pending', 'resolved', 'dismissed'
      -- New: 'pending', 'reviewed', 'resolved', 'rejected'
      UPDATE reports SET status = 'resolved' WHERE status = 'dismissed';
      
      -- Make reported_user_id nullable (since we now support product reports)
      ALTER TABLE reports ALTER COLUMN reported_user_id DROP NOT NULL;
      
      -- Rename reviewed_by if it doesn't match
      ALTER TABLE reports 
      ADD COLUMN IF NOT EXISTS reviewed_by UUID;
      
      -- Drop old constraint if exists
      ALTER TABLE reports 
      DROP CONSTRAINT IF EXISTS reports_status_check;
      
      RAISE NOTICE 'Reports table migrated successfully!';
    ELSE
      RAISE NOTICE 'Reports table already has new structure, skipping migration.';
    END IF;
  ELSE
    RAISE NOTICE 'Reports table does not exist, will be created.';
  END IF;
END $$;

-- =====================================================
-- 3. CREATE/UPDATE ENUM TYPES
-- =====================================================

-- Create report_type enum if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'report_type') THEN
    CREATE TYPE report_type AS ENUM ('user', 'product');
  END IF;
END $$;

-- Create report_status enum if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'report_status') THEN
    CREATE TYPE report_status AS ENUM ('pending', 'reviewed', 'resolved', 'rejected');
  END IF;
END $$;

-- =====================================================
-- 4. CREATE REPORTS TABLE (IF NOT EXISTS)
-- =====================================================

CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    report_type TEXT DEFAULT 'user' CHECK (report_type IN ('user', 'product')),
    reported_user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    reported_product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'rejected')),
    reviewed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    admin_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add constraint: must have either reported_user_id or reported_product_id
ALTER TABLE reports 
DROP CONSTRAINT IF EXISTS check_report_target;

ALTER TABLE reports
ADD CONSTRAINT check_report_target CHECK (
  (report_type = 'user' AND reported_user_id IS NOT NULL AND reported_product_id IS NULL) OR
  (report_type = 'product' AND reported_product_id IS NOT NULL AND reported_user_id IS NULL)
);

-- Add indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_reports_reporter ON reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_user ON reports(reported_user_id) WHERE reported_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reports_product ON reports(reported_product_id) WHERE reported_product_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_type ON reports(report_type);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at DESC);

COMMENT ON TABLE reports IS 'User reports for users and products';
COMMENT ON COLUMN reports.reporter_id IS 'User who submitted the report';
COMMENT ON COLUMN reports.report_type IS 'Type of report: user or product';
COMMENT ON COLUMN reports.reviewed_by IS 'Admin who reviewed the report';

-- =====================================================
-- 5. RLS POLICIES FOR REPORTS
-- =====================================================

ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to recreate
DROP POLICY IF EXISTS "Users can create reports" ON reports;
DROP POLICY IF EXISTS "Users can view their own reports" ON reports;
DROP POLICY IF EXISTS "Admins can view all reports" ON reports;
DROP POLICY IF EXISTS "Admins can read all reports" ON reports;
DROP POLICY IF EXISTS "Admins can update reports" ON reports;

-- Users can create reports (can't report yourself)
CREATE POLICY "Users can create reports"
    ON reports
    FOR INSERT
    WITH CHECK (
      auth.uid() = reporter_id AND
      (
        (report_type = 'user' AND reporter_id != reported_user_id) OR
        report_type = 'product'
      )
    );

-- Users can view their own reports
CREATE POLICY "Users can view their own reports"
    ON reports
    FOR SELECT
    USING (auth.uid() = reporter_id);

-- Admins can view all reports
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
-- 6. UPDATE RLS POLICIES FOR BANNED USERS
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
-- 7. FUNCTIONS
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
DROP TRIGGER IF EXISTS trigger_update_reports_timestamp ON reports;

CREATE TRIGGER update_reports_updated_at
    BEFORE UPDATE ON reports
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to ban user (for admin use)
CREATE OR REPLACE FUNCTION ban_user(
    user_id_param UUID,
    reason_param TEXT,
    admin_id_param UUID DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  admin_check UUID;
BEGIN
    -- Use provided admin_id or current user
    admin_check := COALESCE(admin_id_param, auth.uid());
    
    -- Check if admin
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = admin_check AND role = 'admin') THEN
        RAISE EXCEPTION 'Only admins can ban users';
    END IF;
    
    -- Ban the user
    UPDATE profiles
    SET 
        is_banned = TRUE,
        banned_at = NOW(),
        banned_by = admin_check,
        ban_reason = reason_param
    WHERE id = user_id_param;
    
    -- Set all user's products to unavailable
    UPDATE products
    SET is_available = FALSE
    WHERE owner_id = user_id_param;
    
    RAISE NOTICE 'User % has been banned by admin %', user_id_param, admin_check;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION ban_user IS 'Ban a user and make their products unavailable';

-- Function to unban user (for admin use)
CREATE OR REPLACE FUNCTION unban_user(
    user_id_param UUID,
    admin_id_param UUID DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  admin_check UUID;
BEGIN
    -- Use provided admin_id or current user
    admin_check := COALESCE(admin_id_param, auth.uid());
    
    -- Check if admin
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = admin_check AND role = 'admin') THEN
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
    
    RAISE NOTICE 'User % has been unbanned by admin %', user_id_param, admin_check;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION unban_user IS 'Unban a previously banned user';

-- =====================================================
-- 8. VIEWS FOR ADMIN DASHBOARD
-- =====================================================

-- Drop existing views to recreate
DROP VIEW IF EXISTS admin_reports_view;
DROP VIEW IF EXISTS admin_banned_users_view;
DROP VIEW IF EXISTS admin_stats_view;

-- View for reports with related data
CREATE OR REPLACE VIEW admin_reports_view AS
SELECT 
    r.id,
    r.report_type,
    r.reason,
    r.description,
    r.status,
    r.created_at,
    r.updated_at,
    r.reviewed_at,
    r.admin_notes,
    
    -- Reporter info
    reporter.id AS reporter_id,
    reporter.full_name AS reporter_name,
    reporter.email AS reporter_email,
    reporter.phone_number AS reporter_phone,
    
    -- Reported user info (if applicable)
    reported_user.id AS reported_user_id,
    reported_user.full_name AS reported_user_name,
    reported_user.email AS reported_user_email,
    reported_user.phone_number AS reported_user_phone,
    reported_user.is_banned AS reported_user_is_banned,
    
    -- Reported product info (if applicable)
    reported_product.id AS reported_product_id,
    reported_product.name AS reported_product_name,
    reported_product.owner_id AS reported_product_owner_id,
    
    -- Admin reviewer info
    reviewer.id AS reviewed_by_id,
    reviewer.full_name AS reviewed_by_name,
    reviewer.email AS reviewed_by_email
    
FROM reports r
INNER JOIN profiles reporter ON r.reporter_id = reporter.id
LEFT JOIN profiles reported_user ON r.reported_user_id = reported_user.id
LEFT JOIN products reported_product ON r.reported_product_id = reported_product.id
LEFT JOIN profiles reviewer ON r.reviewed_by = reviewer.id;

COMMENT ON VIEW admin_reports_view IS 'Complete report information for admin dashboard';

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
    (SELECT COUNT(*) FROM bookings WHERE status::TEXT = 'pending') AS pending_bookings,
    (SELECT COUNT(*) FROM bookings WHERE status::TEXT = 'active') AS active_bookings,
    (SELECT COUNT(*) FROM bookings WHERE created_at > NOW() - INTERVAL '30 days') AS new_bookings_30d,
    
    -- Report stats
    (SELECT COUNT(*) FROM reports) AS total_reports,
    (SELECT COUNT(*) FROM reports WHERE status = 'pending') AS pending_reports,
    (SELECT COUNT(*) FROM reports WHERE status = 'resolved') AS resolved_reports,
    (SELECT COUNT(*) FROM reports WHERE created_at > NOW() - INTERVAL '30 days') AS new_reports_30d;

COMMENT ON VIEW admin_stats_view IS 'Dashboard statistics for admin';

-- Grant access to views for authenticated users
GRANT SELECT ON admin_reports_view TO authenticated;
GRANT SELECT ON admin_banned_users_view TO authenticated;
GRANT SELECT ON admin_stats_view TO authenticated;

-- =====================================================
-- 9. VERIFICATION & CLEANUP
-- =====================================================

-- Show success message
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '================================================';
  RAISE NOTICE 'ADMIN FEATURES MIGRATION COMPLETED SUCCESSFULLY!';
  RAISE NOTICE '================================================';
  RAISE NOTICE '';
  RAISE NOTICE 'To create your first admin user, run:';
  RAISE NOTICE 'UPDATE profiles SET role = ''admin'' WHERE email = ''your-email@example.com'';';
  RAISE NOTICE '';
END $$;

-- =====================================================
-- 10. VERIFICATION QUERIES (commented out)
-- =====================================================

-- Check if columns exist
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'profiles' 
-- AND column_name IN ('role', 'is_banned', 'banned_at', 'banned_by', 'ban_reason');

-- Check if reports table has correct structure
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'reports'
-- ORDER BY ordinal_position;

-- Check admin users
-- SELECT id, email, full_name, role FROM profiles WHERE role = 'admin';

-- Check statistics
-- SELECT * FROM admin_stats_view;

-- =====================================================
-- END OF MIGRATION
-- =====================================================
