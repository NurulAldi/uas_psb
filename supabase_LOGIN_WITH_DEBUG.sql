-- ============================================================================
-- LOGIN FUNCTION WITH DEBUG LOGGING
-- ============================================================================

DROP FUNCTION IF EXISTS public.login_user(TEXT, TEXT);

CREATE FUNCTION public.login_user(
    p_username TEXT,
    p_password TEXT
) RETURNS JSON AS $$
DECLARE
    v_user_record RECORD;
    v_result JSON;
BEGIN
    RAISE NOTICE '=== LOGIN DEBUG ===';
    RAISE NOTICE 'Input Username: |%|', p_username;
    RAISE NOTICE 'Input Password: |%|', p_password;
    RAISE NOTICE 'Input Username Length: %', LENGTH(p_username);
    RAISE NOTICE 'Input Password Length: %', LENGTH(p_password);
    
    -- Find user by username
    SELECT * INTO v_user_record
    FROM public.users
    WHERE username = p_username;
    
    -- User not found
    IF NOT FOUND THEN
        RAISE NOTICE 'User NOT FOUND: %', p_username;
        RETURN json_build_object(
            'success', false,
            'error', 'Username atau password salah'
        );
    END IF;
    
    RAISE NOTICE 'User FOUND: %', v_user_record.username;
    RAISE NOTICE 'DB Password: |%|', v_user_record.password;
    RAISE NOTICE 'DB Password Length: %', LENGTH(v_user_record.password);
    RAISE NOTICE 'Password Match: %', v_user_record.password = p_password;
    RAISE NOTICE 'Password Match (trimmed): %', TRIM(v_user_record.password) = TRIM(p_password);
    
    -- Check if user is banned
    IF v_user_record.is_banned THEN
        RAISE NOTICE 'User is BANNED';
        RETURN json_build_object(
            'success', false,
            'error', 'ACCOUNT_BANNED'
        );
    END IF;
    
    -- Verify password (PLAINTEXT COMPARISON - DEMO ONLY!)
    -- TAMBAHKAN TRIM untuk handle whitespace
    IF TRIM(v_user_record.password) != TRIM(p_password) THEN
        RAISE NOTICE 'Password MISMATCH!';
        RAISE NOTICE 'Expected (trimmed): |%|', TRIM(v_user_record.password);
        RAISE NOTICE 'Got (trimmed): |%|', TRIM(p_password);
        RETURN json_build_object(
            'success', false,
            'error', 'Username atau password salah'
        );
    END IF;
    
    RAISE NOTICE 'Login SUCCESS!';
    
    -- Update last login time
    UPDATE public.users
    SET last_login_at = NOW()
    WHERE id = v_user_record.id;
    
    -- Return success with user data (excluding password)
    SELECT json_build_object(
        'success', true,
        'user', json_build_object(
            'id', v_user_record.id,
            'username', v_user_record.username,
            'full_name', v_user_record.full_name,
            'email', v_user_record.email,
            'phone_number', v_user_record.phone_number,
            'avatar_url', v_user_record.avatar_url,
            'role', v_user_record.role,
            'is_banned', v_user_record.is_banned,
            'latitude', v_user_record.latitude,
            'longitude', v_user_record.longitude,
            'address', v_user_record.address,
            'city', v_user_record.city,
            'created_at', v_user_record.created_at,
            'updated_at', v_user_record.updated_at,
            'last_login_at', NOW()
        )
    ) INTO v_result;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Test dengan debug output
SELECT public.login_user('admin', 'admin123');
