-- =====================================================
-- FIX: Bookings SELECT RLS Policy Security Issue
-- =====================================================
-- Issue: Current SELECT policy allows anyone to view all bookings
-- This is a major security vulnerability where users can see
-- other users' booking data
-- =====================================================

-- Drop the insecure permissive SELECT policy
DROP POLICY IF EXISTS "Anyone can view bookings" ON bookings;

-- Drop any existing policies that might conflict
DROP POLICY IF EXISTS "Users can view own bookings or owned product bookings" ON bookings;

-- Create secure SELECT policy that only allows users to view their own bookings
-- SIMPLIFIED VERSION: Only check user_id for now to isolate the issue
CREATE POLICY "Users can view their own bookings"
    ON bookings
    FOR SELECT
    USING (
        user_id::text = current_setting('app.current_user_id', true)
    );

COMMENT ON POLICY "Users can view their own bookings" ON bookings IS 'Users can only view their own bookings (simplified for debugging)';

-- Create function to set user context for RLS
CREATE OR REPLACE FUNCTION set_user_context(user_id UUID)
RETURNS VOID AS $$
BEGIN
  -- Set the current user ID in session
  PERFORM set_config('app.current_user_id', user_id::text, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get current user context (for debugging)
CREATE OR REPLACE FUNCTION get_current_user_context()
RETURNS TEXT AS $$
BEGIN
  RETURN current_setting('app.current_user_id', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;