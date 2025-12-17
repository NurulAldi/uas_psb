-- ============================================================================
-- DEBUG: Check Users Table and Password Comparison
-- ============================================================================

-- 1. Lihat semua user dengan password aktual
SELECT 
    username,
    password,
    LENGTH(password) as password_length,
    role,
    is_banned,
    '|' || password || '|' as password_with_pipes  -- untuk lihat whitespace
FROM public.users
ORDER BY username;

-- 2. Test login dengan data aktual dari database
-- Ganti 'admin' dan 'admin123' dengan data yang kamu coba login
DO $$
DECLARE
    v_username TEXT := 'admin';  -- GANTI INI
    v_password TEXT := 'admin123';  -- GANTI INI
    v_db_password TEXT;
    v_found BOOLEAN;
BEGIN
    -- Check if user exists
    SELECT password, TRUE INTO v_db_password, v_found
    FROM public.users 
    WHERE username = v_username;
    
    IF v_found THEN
        RAISE NOTICE 'User ditemukan: %', v_username;
        RAISE NOTICE 'Password di database: |%|', v_db_password;
        RAISE NOTICE 'Password yang diinput: |%|', v_password;
        RAISE NOTICE 'Length password DB: %', LENGTH(v_db_password);
        RAISE NOTICE 'Length password input: %', LENGTH(v_password);
        RAISE NOTICE 'Password match: %', v_db_password = v_password;
        RAISE NOTICE 'Password match (trimmed): %', TRIM(v_db_password) = TRIM(v_password);
    ELSE
        RAISE NOTICE 'User TIDAK ditemukan: %', v_username;
    END IF;
END $$;

-- 3. Test function login_user langsung
SELECT public.login_user('admin', 'admin123');

-- 4. Cek apakah ada hidden characters
SELECT 
    username,
    password,
    encode(password::bytea, 'hex') as password_hex,
    LENGTH(password) as len
FROM public.users
WHERE username = 'admin';
