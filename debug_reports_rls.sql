-- =====================================================
-- DEBUG: Check Reports RLS Status and Policies
-- =====================================================

-- Check if RLS is enabled on reports table
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE tablename = 'reports';

-- Check all policies on reports table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'reports'
ORDER BY policyname;

-- Test current_setting function
SELECT current_setting('app.current_user_id', true) as current_user_setting;

-- Check if set_user_context function exists
SELECT proname, pg_get_function_identity_arguments(oid) as args
FROM pg_proc
WHERE proname = 'set_user_context';

-- Test set_user_context function (replace with actual UUID)
-- SELECT set_user_context('f70b2ab1-c852-477d-9ca8-ca00622932e0');
-- SELECT current_setting('app.current_user_id', true) as user_after_set;