-- ============================================================================
-- CONVERT PASSWORD HASH TO PLAINTEXT (FOR DEMO/ACADEMIC ONLY!)
-- ============================================================================
-- ⚠️ WARNING: This removes password security completely!
-- ⚠️ ONLY use for demo/academic presentations
-- ⚠️ NEVER use in production!
-- ============================================================================

-- Step 1: Rename password_hash column to password
ALTER TABLE public.users 
RENAME COLUMN password_hash TO password;

-- Step 2: Update existing accounts with plaintext passwords
UPDATE public.users SET password = 'admin123' WHERE username = 'admin';
UPDATE public.users SET password = 'password123' WHERE username IN ('user1', 'user2');
UPDATE public.users SET password = 'demo123' WHERE username = 'demo';

-- Step 3: Verify conversion
SELECT 
    username,
    password,
    full_name,
    role
FROM public.users
WHERE username IN ('admin', 'user1', 'user2', 'demo')
ORDER BY username;

-- ============================================================================
-- CREDENTIALS AFTER CONVERSION
-- ============================================================================
-- Username: admin  | Password: admin123
-- Username: user1  | Password: password123
-- Username: user2  | Password: password123
-- Username: demo   | Password: demo123
-- ============================================================================
