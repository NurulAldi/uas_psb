-- =====================================================
-- Role-Based Access Control (RBAC) and Reporting System
-- Supabase SQL Migration Script
-- =====================================================
-- Description: Adds role management and user reporting features
-- Date: 2025-12-02
-- =====================================================

-- =====================================================
-- STEP 1: MODIFY PROFILES TABLE
-- =====================================================

-- Add role column with check constraint
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user'
CHECK (role IN ('user', 'admin'));

-- Add is_banned column
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT false;

-- Create index for faster role queries (optional but recommended)
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_is_banned ON profiles(is_banned);

-- =====================================================
-- STEP 2: CREATE REPORTS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  created_at TIMESTAMPTZ DEFAULT now(),
  
  -- Reporter information
  reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  
  -- Reported user information
  reported_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  
  -- Report details
  reason TEXT NOT NULL,
  
  -- Report status
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'dismissed')),
  
  -- Metadata
  updated_at TIMESTAMPTZ DEFAULT now(),
  resolved_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  admin_notes TEXT
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_reports_reporter_id ON reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_reports_reported_user_id ON reports(reported_user_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at DESC);

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_reports_timestamp
BEFORE UPDATE ON reports
FOR EACH ROW
EXECUTE FUNCTION update_reports_updated_at();

-- =====================================================
-- STEP 3: DROP EXISTING POLICIES (if any)
-- =====================================================

-- Drop old profiles policies (to recreate with new rules)
DROP POLICY IF EXISTS "Users can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile on signup" ON profiles;

-- Drop any existing reports policies
DROP POLICY IF EXISTS "Users can create reports" ON reports;
DROP POLICY IF EXISTS "Admins can read all reports" ON reports;
DROP POLICY IF EXISTS "Admins can update reports" ON reports;

-- =====================================================
-- STEP 4: CREATE RLS POLICIES FOR PROFILES TABLE
-- =====================================================

-- Enable RLS on profiles table
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view all profiles (for marketplace browsing)
CREATE POLICY "Anyone can view all profiles"
ON profiles FOR SELECT
USING (true);

-- Policy: Users can only insert their own profile during signup
CREATE POLICY "Users can insert own profile on signup"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- Policy: Users can ONLY update their own full_name and avatar_url
-- They CANNOT update role or is_banned
CREATE POLICY "Users can update own profile (limited fields)"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (
  auth.uid() = id 
  AND (
    -- Check that role and is_banned are NOT being changed
    -- or are being set to their current values
    (role IS NOT DISTINCT FROM (SELECT role FROM profiles WHERE id = auth.uid()))
    AND (is_banned IS NOT DISTINCT FROM (SELECT is_banned FROM profiles WHERE id = auth.uid()))
  )
);

-- Policy: Only admins can update role and is_banned
CREATE POLICY "Admins can update any profile"
ON profiles FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- =====================================================
-- STEP 5: CREATE RLS POLICIES FOR REPORTS TABLE
-- =====================================================

-- Enable RLS on reports table
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Policy: Authenticated users can create reports
CREATE POLICY "Users can create reports"
ON reports FOR INSERT
WITH CHECK (
  auth.role() = 'authenticated'
  AND reporter_id = auth.uid()
  AND reporter_id != reported_user_id -- Can't report yourself
);

-- Policy: Only admins can read all reports
CREATE POLICY "Admins can read all reports"
ON reports FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Policy: Only admins can update reports
CREATE POLICY "Admins can update reports"
ON reports FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- Policy: Users can view their own submitted reports (optional)
CREATE POLICY "Users can view their own reports"
ON reports FOR SELECT
USING (reporter_id = auth.uid());

-- =====================================================
-- STEP 6: CREATE HELPER FUNCTIONS
-- =====================================================

-- Function to check if current user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to ban a user (admin only)
CREATE OR REPLACE FUNCTION ban_user(user_id UUID)
RETURNS VOID AS $$
BEGIN
  -- Check if caller is admin
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only admins can ban users';
  END IF;
  
  -- Ban the user
  UPDATE profiles 
  SET is_banned = true 
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to unban a user (admin only)
CREATE OR REPLACE FUNCTION unban_user(user_id UUID)
RETURNS VOID AS $$
BEGIN
  -- Check if caller is admin
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only admins can unban users';
  END IF;
  
  -- Unban the user
  UPDATE profiles 
  SET is_banned = false 
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to resolve a report (admin only)
CREATE OR REPLACE FUNCTION resolve_report(
  report_id UUID,
  resolution_status TEXT,
  notes TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  -- Check if caller is admin
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Only admins can resolve reports';
  END IF;
  
  -- Validate status
  IF resolution_status NOT IN ('resolved', 'dismissed') THEN
    RAISE EXCEPTION 'Invalid status. Must be resolved or dismissed.';
  END IF;
  
  -- Update report
  UPDATE reports 
  SET 
    status = resolution_status,
    resolved_by = auth.uid(),
    admin_notes = notes,
    updated_at = now()
  WHERE id = report_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- STEP 7: CREATE VIEWS FOR ADMINS
-- =====================================================

-- View: Report statistics by user
CREATE OR REPLACE VIEW report_statistics AS
SELECT 
  p.id AS user_id,
  p.full_name,
  p.email,
  p.is_banned,
  COUNT(r.id) AS total_reports,
  COUNT(CASE WHEN r.status = 'pending' THEN 1 END) AS pending_reports,
  COUNT(CASE WHEN r.status = 'resolved' THEN 1 END) AS resolved_reports,
  COUNT(CASE WHEN r.status = 'dismissed' THEN 1 END) AS dismissed_reports
FROM profiles p
LEFT JOIN reports r ON p.id = r.reported_user_id
GROUP BY p.id, p.full_name, p.email, p.is_banned
ORDER BY total_reports DESC;

-- View: Recent reports with details
CREATE OR REPLACE VIEW recent_reports_with_details AS
SELECT 
  r.id,
  r.created_at,
  r.status,
  r.reason,
  r.admin_notes,
  reporter.full_name AS reporter_name,
  reporter.email AS reporter_email,
  reported.full_name AS reported_user_name,
  reported.email AS reported_user_email,
  reported.is_banned AS reported_user_is_banned,
  admin.full_name AS resolved_by_name
FROM reports r
JOIN profiles reporter ON r.reporter_id = reporter.id
JOIN profiles reported ON r.reported_user_id = reported.id
LEFT JOIN profiles admin ON r.resolved_by = admin.id
ORDER BY r.created_at DESC;

-- =====================================================
-- STEP 8: VERIFICATION QUERIES
-- =====================================================

-- Uncomment these to verify the setup:

-- Check profiles table schema
-- SELECT column_name, data_type, column_default, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'profiles'
-- ORDER BY ordinal_position;

-- Check reports table schema
-- SELECT column_name, data_type, column_default, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'reports'
-- ORDER BY ordinal_position;

-- Check RLS policies on profiles
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
-- FROM pg_policies
-- WHERE tablename = 'profiles';

-- Check RLS policies on reports
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
-- FROM pg_policies
-- WHERE tablename = 'reports';

-- =====================================================
-- STEP 9: MANUAL SETUP INSTRUCTIONS
-- =====================================================

/*
IMPORTANT: To set your first admin user manually:

1. Open Supabase Dashboard
2. Go to Table Editor → profiles
3. Find your user account (by email or id)
4. Click the row to edit
5. Change 'role' column from 'user' to 'admin'
6. Save changes

Your account now has admin privileges!

To test admin functions:
- Try calling: SELECT is_admin(); (should return true)
- Try viewing reports: SELECT * FROM reports; (should see all reports)
- Try banning a user: SELECT ban_user('user-uuid-here');
*/

-- =====================================================
-- STEP 10: SAMPLE DATA (Optional - for testing)
-- =====================================================

-- Uncomment to insert test data:

/*
-- Insert a test report (replace UUIDs with real ones from your profiles table)
INSERT INTO reports (reporter_id, reported_user_id, reason)
VALUES (
  'reporter-uuid-here',
  'reported-user-uuid-here',
  'Test report: User is spamming the marketplace'
);
*/

-- =====================================================
-- END OF MIGRATION SCRIPT
-- =====================================================

-- Migration complete! Your RBAC and Reporting System is now ready.
-- Remember to manually promote your first admin via Supabase Dashboard.
