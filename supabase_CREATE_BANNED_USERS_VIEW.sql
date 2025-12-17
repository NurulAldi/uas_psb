-- =====================================================
-- CREATE BANNED USERS VIEW (FIX)
-- =====================================================
-- Purpose: Create the missing admin_banned_users_view
-- Run this in Supabase SQL Editor
-- =====================================================

-- =====================================================
-- STEP 1: Ensure all required columns exist
-- =====================================================

-- Add ban_reason column if not exists
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS ban_reason TEXT;

-- Add is_banned column if not exists
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE;

-- Add banned_at column if not exists
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS banned_at TIMESTAMPTZ;

-- Add banned_by column if not exists
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS banned_by UUID;

-- Add foreign key constraint if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'users_banned_by_fkey'
  ) THEN
    ALTER TABLE users 
    ADD CONSTRAINT users_banned_by_fkey 
    FOREIGN KEY (banned_by) REFERENCES users(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Add comments
COMMENT ON COLUMN users.is_banned IS 'Whether the user is banned from the platform';
COMMENT ON COLUMN users.banned_at IS 'Timestamp when the user was banned';
COMMENT ON COLUMN users.banned_by IS 'Admin user who banned this user';
COMMENT ON COLUMN users.ban_reason IS 'Reason for banning the user';

-- =====================================================
-- STEP 2: Create or replace the view
-- =====================================================

-- Drop view if exists (untuk memastikan fresh install)
DROP VIEW IF EXISTS admin_banned_users_view;

-- Create view for banned users
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
    
FROM users u
LEFT JOIN users a ON u.banned_by = a.id
WHERE u.is_banned = TRUE
ORDER BY u.banned_at DESC;

-- Add comment
COMMENT ON VIEW admin_banned_users_view IS 'List of banned users with statistics';

-- Grant permissions
GRANT SELECT ON admin_banned_users_view TO authenticated;

-- =====================================================
-- STEP 3: Test the view
-- =====================================================

-- Test the view (should return empty result if no banned users)
SELECT * FROM admin_banned_users_view LIMIT 1;

-- Verify columns exist
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('is_banned', 'banned_at', 'banned_by', 'ban_reason')
ORDER BY column_name;
