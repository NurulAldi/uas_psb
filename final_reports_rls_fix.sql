-- =====================================================
-- FINAL FIX: Remove Conflicting RLS Policies
-- =====================================================
-- Issue: "Users can view their own reports" policy uses auth.uid()
-- which conflicts with manual authentication system
-- =====================================================

-- Drop the problematic policy that uses auth.uid()
DROP POLICY IF EXISTS "Users can view their own reports" ON reports;

-- Keep only the policies that work with manual auth:
-- 1. "Users can create reports" (INSERT with WITH CHECK (true))
-- 2. "Admins can read all reports" (SELECT for admins)
-- 3. "Admins can update reports" (UPDATE for admins)

-- Optional: Add a proper SELECT policy for users to view their own reports
-- This policy allows users to see reports they created
CREATE POLICY "Users can view their own reports"
ON reports FOR SELECT
USING (
  reporter_id::text = current_setting('app.current_user_id', true)
);

COMMENT ON POLICY "Users can view their own reports" ON reports IS 'Users can view reports they created (manual auth compatible)';