-- ============================================================================
-- UPDATE PASSWORD HASHES - FIX LOGIN ISSUE
-- ============================================================================
-- Run this SQL in Supabase SQL Editor to fix password validation
-- This updates existing demo accounts with correct SHA-256 hashes
-- ============================================================================

-- Update admin account (username: admin, password: admin123)
UPDATE public.users 
SET password_hash = '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9' 
WHERE username = 'admin';

-- Update regular users (username: user1/user2, password: password123)
UPDATE public.users 
SET password_hash = 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f' 
WHERE username IN ('user1', 'user2');

-- Update demo account (username: demo, password: demo123)
UPDATE public.users 
SET password_hash = 'd3ad9315b7be5dd53b31a273b3b3aba5defe700808305aa16a3062b76658a791' 
WHERE username = 'demo';

-- Verify the updates
SELECT 
    username, 
    full_name, 
    role,
    CASE 
        WHEN password_hash = '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9' THEN '✓ admin123'
        WHEN password_hash = 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f' THEN '✓ password123'
        WHEN password_hash = 'd3ad9315b7be5dd53b31a273b3b3aba5defe700808305aa16a3062b76658a791' THEN '✓ demo123'
        ELSE '✗ Invalid hash'
    END as password_status
FROM public.users
WHERE username IN ('admin', 'user1', 'user2', 'demo')
ORDER BY username;

-- ============================================================================
-- CREDENTIALS FOR LOGIN
-- ============================================================================
-- Username: admin      | Password: admin123
-- Username: user1      | Password: password123
-- Username: user2      | Password: password123
-- Username: demo       | Password: demo123
-- ============================================================================
