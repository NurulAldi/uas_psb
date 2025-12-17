-- ============================================================================
-- LOGIN WITH USERNAME OR EMAIL
-- ============================================================================

DROP FUNCTION IF EXISTS public.login_user(TEXT, TEXT);

CREATE FUNCTION public.login_user(
    p_username_or_email TEXT,
    p_password TEXT
) RETURNS JSON AS $$
DECLARE
    v_user_record RECORD;
    v_result JSON;
BEGIN
    -- Find user by username OR email
    SELECT * INTO v_user_record
    FROM public.users
    WHERE username = p_username_or_email 
       OR email = p_username_or_email;
    
    -- User not found
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Username/Email atau password salah'
        );
    END IF;
    
    -- Check if user is banned
    IF v_user_record.is_banned THEN
        RETURN json_build_object(
            'success', false,
            'error', 'ACCOUNT_BANNED'
        );
    END IF;
    
    -- Verify password
    IF TRIM(v_user_record.password) != TRIM(p_password) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Username/Email atau password salah'
        );
    END IF;
    
    -- Update last login time
    UPDATE public.users
    SET last_login_at = NOW()
    WHERE id = v_user_record.id;
    
    -- Return success with user data
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

-- Test login dengan username
SELECT public.login_user('admin', 'admin123');

-- Test login dengan email
SELECT public.login_user('admin@demo.com', 'admin123');
