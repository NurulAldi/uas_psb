-- =====================================================
-- ADMIN VIEWS AND FUNCTIONS FIX (USERS TABLE)
-- =====================================================
-- Purpose: Create all missing admin views and functions
-- Table: Uses 'users' NOT 'profiles'
-- Run this in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- DEBUG: CHECK CURRENT RLS POLICIES
-- =====================================================

-- Check what policies exist on products table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'products'
ORDER BY policyname;

-- Create debug function to check current_setting
CREATE OR REPLACE FUNCTION get_current_setting(setting_name TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN current_setting(setting_name, true);
EXCEPTION
  WHEN OTHERS THEN
    RETURN 'NOT_SET';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- FIX RLS POLICIES FOR PRODUCTS TABLE
-- =====================================================

-- Drop existing conflicting policies
DROP POLICY IF EXISTS "Allow all operations on products for development" ON products;
DROP POLICY IF EXISTS "Anyone can view all products" ON products;
DROP POLICY IF EXISTS "Users can create their own products" ON products;
DROP POLICY IF EXISTS "Users can update their own products" ON products;
DROP POLICY IF EXISTS "Users can delete their own products" ON products;

-- Enable RLS on products table
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Policy 1: Anyone can view/read all products (public marketplace)
CREATE POLICY "Anyone can view all products"
    ON products
    FOR SELECT
    USING (true);

-- Create function to set user context for RLS
CREATE OR REPLACE FUNCTION set_user_context(user_id UUID)
RETURNS VOID AS $$
BEGIN
  -- Set the current user ID in session
  PERFORM set_config('app.current_user_id', user_id::text, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Policy 2: Authenticated users can insert their own products
-- Uses current_setting for custom authentication
CREATE POLICY "Users can create their own products"
    ON products
    FOR INSERT
    WITH CHECK (
        owner_id = (current_setting('app.current_user_id', true)::UUID)
        AND owner_id IS NOT NULL
    );

-- Policy 3: Users can only update their own products
CREATE POLICY "Users can update their own products"
    ON products
    FOR UPDATE
    USING (owner_id = (current_setting('app.current_user_id', true)::UUID))
    WITH CHECK (owner_id = (current_setting('app.current_user_id', true)::UUID));

-- Policy 4: Users can only delete their own products
CREATE POLICY "Users can delete their own products"
    ON products
    FOR DELETE
    USING (owner_id = (current_setting('app.current_user_id', true)::UUID));

-- =====================================================
-- ADMIN: Update Report Status function
-- =====================================================

CREATE OR REPLACE FUNCTION public.admin_update_report_status(
  p_report_id UUID,
  p_status TEXT,
  p_admin_id UUID,
  p_admin_notes TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  updated_row reports%ROWTYPE;
  result JSON;
  is_admin BOOLEAN;
BEGIN
  -- Verify admin exists and has role 'admin'
  SELECT EXISTS (SELECT 1 FROM users WHERE id = p_admin_id AND role = 'admin') INTO is_admin;
  IF NOT is_admin THEN
    result := json_build_object('success', false, 'error', 'Not an admin');
    RETURN result;
  END IF;

  -- Perform update
  UPDATE reports
  SET status = p_status,
      reviewed_by = p_admin_id,
      reviewed_at = NOW(),
      admin_notes = p_admin_notes,
      updated_at = NOW()
  WHERE id = p_report_id
  RETURNING * INTO updated_row;

  IF FOUND THEN
    result := json_build_object('success', true, 'data', row_to_json(updated_row));
  ELSE
    result := json_build_object('success', false, 'error', 'No rows updated');
  END IF;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- END RLS POLICIES FIX
-- =====================================================

-- =====================================================
-- PART 0: ENSURE REPORTS TABLE EXISTS WITH CORRECT COLUMNS
-- =====================================================

-- Create reports table if not exists
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    report_type TEXT DEFAULT 'user' CHECK (report_type IN ('user', 'product')),
    reported_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    reported_product_id UUID REFERENCES products(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    description TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'resolved', 'rejected')),
    reviewed_by UUID REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    admin_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add missing columns if they don't exist
ALTER TABLE reports ADD COLUMN IF NOT EXISTS report_type TEXT DEFAULT 'user';
ALTER TABLE reports ADD COLUMN IF NOT EXISTS reported_product_id UUID;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS reviewed_by UUID;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS admin_notes TEXT;

-- Update check constraints (drop old ones first)
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_report_type_check;
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_status_check;
ALTER TABLE reports DROP CONSTRAINT IF EXISTS check_report_target;

-- Add new constraints
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'reports_report_type_check'
  ) THEN
    ALTER TABLE reports 
    ADD CONSTRAINT reports_report_type_check 
    CHECK (report_type IN ('user', 'product'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'reports_status_check'
  ) THEN
    ALTER TABLE reports 
    ADD CONSTRAINT reports_status_check 
    CHECK (status IN ('pending', 'reviewing', 'resolved', 'rejected'));
  END IF;
END $$;

-- Add foreign key for reported_product_id if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'reports_reported_product_id_fkey'
  ) THEN
    ALTER TABLE reports 
    ADD CONSTRAINT reports_reported_product_id_fkey 
    FOREIGN KEY (reported_product_id) REFERENCES products(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Add foreign key for reviewed_by if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'reports_reviewed_by_fkey'
  ) THEN
    ALTER TABLE reports 
    ADD CONSTRAINT reports_reviewed_by_fkey 
    FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Update existing foreign keys to use users table
DO $$
BEGIN
  -- Update reporter_id foreign key
  ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_reporter_id_fkey;
  ALTER TABLE reports ADD CONSTRAINT reports_reporter_id_fkey 
    FOREIGN KEY (reporter_id) REFERENCES users(id) ON DELETE CASCADE;
  
  -- Update reported_user_id foreign key
  ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_reported_user_id_fkey;
  ALTER TABLE reports ADD CONSTRAINT reports_reported_user_id_fkey 
    FOREIGN KEY (reported_user_id) REFERENCES users(id) ON DELETE CASCADE;
END $$;

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_reports_reporter ON reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_user ON reports(reported_user_id) WHERE reported_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reports_product ON reports(reported_product_id) WHERE reported_product_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_type ON reports(report_type);

-- =====================================================
-- PART 1: CREATE admin_reports_view
-- =====================================================

-- Drop view if exists
DROP VIEW IF EXISTS admin_reports_view;

-- Create view for reports with related data
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
INNER JOIN users reporter ON r.reporter_id = reporter.id
LEFT JOIN users reported_user ON r.reported_user_id = reported_user.id
LEFT JOIN products reported_product ON r.reported_product_id = reported_product.id
LEFT JOIN users reviewer ON r.reviewed_by = reviewer.id;

-- Add comment
COMMENT ON VIEW admin_reports_view IS 'Complete report information for admin dashboard';

-- Grant permissions
GRANT SELECT ON admin_reports_view TO authenticated;

-- =====================================================
-- PART 2: CREATE admin_stats_view
-- =====================================================

-- Drop view if exists
DROP VIEW IF EXISTS admin_stats_view;

-- Create view for admin statistics
CREATE OR REPLACE VIEW admin_stats_view AS
SELECT
    -- User stats
    (SELECT COUNT(*) FROM users) AS total_users,
    (SELECT COUNT(*) FROM users WHERE role = 'admin') AS total_admins,
    (SELECT COUNT(*) FROM users WHERE is_banned = TRUE) AS total_banned_users,
    
    -- Product stats (using is_available instead of status)
    (SELECT COUNT(*) FROM products) AS total_products,
    (SELECT COUNT(*) FROM products WHERE is_available = TRUE) AS available_products,
    (SELECT COUNT(*) FROM products WHERE is_available = FALSE) AS unavailable_products,
    
    -- Booking stats
    (SELECT COUNT(*) FROM bookings) AS total_bookings,
    (SELECT COUNT(*) FROM bookings WHERE status = 'pending') AS pending_bookings,
    (SELECT COUNT(*) FROM bookings WHERE status = 'confirmed') AS confirmed_bookings,
    (SELECT COUNT(*) FROM bookings WHERE status = 'active') AS active_bookings,
    (SELECT COUNT(*) FROM bookings WHERE status = 'completed') AS completed_bookings,
    
    -- Report stats
    (SELECT COUNT(*) FROM reports) AS total_reports,
    (SELECT COUNT(*) FROM reports WHERE status = 'pending') AS pending_reports,
    (SELECT COUNT(*) FROM reports WHERE status = 'reviewing') AS reviewing_reports,
    (SELECT COUNT(*) FROM reports WHERE status = 'resolved') AS resolved_reports,
    
    -- Revenue stats (using correct payment_status enum values)
    (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status = 'paid') AS total_revenue,
    (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status = 'pending') AS pending_revenue,
    (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE status = 'processing') AS processing_revenue;

-- Add comment
COMMENT ON VIEW admin_stats_view IS 'Dashboard statistics for admin panel';

-- Grant permissions
GRANT SELECT ON admin_stats_view TO authenticated;

-- =====================================================
-- PART 3: CREATE FUNCTIONS FOR BAN/UNBAN
-- =====================================================

-- Drop existing functions if they exist (with CASCADE to remove all versions)
DROP FUNCTION IF EXISTS admin_ban_user CASCADE;
DROP FUNCTION IF EXISTS admin_unban_user CASCADE;

-- Function to ban a user (with better error handling)
CREATE OR REPLACE FUNCTION admin_ban_user(
    p_user_id UUID,
    p_admin_id UUID,
    p_reason TEXT
) RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    -- Check if user exists
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User tidak ditemukan'
        );
    END IF;
    
    -- Check if admin exists and is admin
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_admin_id AND role = 'admin') THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Hanya admin yang bisa ban user'
        );
    END IF;
    
    -- Check if user is already banned
    IF EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND is_banned = TRUE) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User sudah dalam status banned'
        );
    END IF;
    
    -- Ban the user
    UPDATE users 
    SET 
        is_banned = TRUE,
        banned_at = NOW(),
        banned_by = p_admin_id,
        ban_reason = p_reason,
        updated_at = NOW()
    WHERE id = p_user_id;
    
    -- Return success
    RETURN json_build_object(
        'success', true,
        'message', 'User berhasil di-ban',
        'user_id', p_user_id,
        'banned_at', NOW()
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to unban a user
CREATE OR REPLACE FUNCTION admin_unban_user(
    p_user_id UUID
) RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    -- Check if user exists
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User tidak ditemukan'
        );
    END IF;
    
    -- Check if user is actually banned
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND is_banned = TRUE) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'User tidak dalam status banned'
        );
    END IF;
    
    -- Unban the user
    UPDATE users 
    SET 
        is_banned = FALSE,
        banned_at = NULL,
        banned_by = NULL,
        ban_reason = NULL,
        updated_at = NOW()
    WHERE id = p_user_id;
    
    -- Return success
    RETURN json_build_object(
        'success', true,
        'message', 'User berhasil di-unban',
        'user_id', p_user_id
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comments
COMMENT ON FUNCTION admin_ban_user IS 'Ban a user with reason (returns JSON with success/error)';
COMMENT ON FUNCTION admin_unban_user IS 'Unban a user (returns JSON with success/error)';

-- =====================================================
-- PART 4: TEST ALL VIEWS AND FUNCTIONS
-- =====================================================

-- Test admin_reports_view
SELECT 'Testing admin_reports_view...' AS test;
SELECT * FROM admin_reports_view LIMIT 1;

-- Test admin_banned_users_view
SELECT 'Testing admin_banned_users_view...' AS test;
SELECT * FROM admin_banned_users_view LIMIT 1;

-- Test admin_stats_view
SELECT 'Testing admin_stats_view...' AS test;
SELECT * FROM admin_stats_view;

-- Verify all columns in users table
SELECT 'Verifying users table columns...' AS test;
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('is_banned', 'banned_at', 'banned_by', 'ban_reason')
ORDER BY column_name;

-- Verify functions exist
SELECT 'Verifying admin functions...' AS test;
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('admin_ban_user', 'admin_unban_user')
ORDER BY routine_name;

-- Test ban function with mock data (you need to replace UUIDs)
SELECT 'Testing ban function (will fail without valid UUIDs - that is expected)...' AS test;
-- Uncomment and replace UUIDs to test:
-- SELECT admin_ban_user(
--     'user-uuid-here'::UUID,
--     'admin-uuid-here'::UUID,
--     'Test ban reason'
-- );

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

SELECT '✅ All admin views and functions created successfully!' AS status;
SELECT '📋 Next steps:' AS info;
SELECT '   1. Run flutter clean && flutter pub get' AS step1;
SELECT '   2. Restart Flutter app' AS step2;
SELECT '   3. Try banning a user and check console logs' AS step3;
SELECT '   4. Check detailed logs for debugging' AS step4;
