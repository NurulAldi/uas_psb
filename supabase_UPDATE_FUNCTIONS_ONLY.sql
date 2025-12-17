-- ============================================================================
-- UPDATE AUTHENTICATION FUNCTIONS ONLY (PLAINTEXT PASSWORD)
-- ============================================================================
-- Quick fix: Update login_user and register_user functions
-- ============================================================================

-- Drop old functions to avoid conflicts
DROP FUNCTION IF EXISTS public.register_user(TEXT, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.login_user(TEXT, TEXT);

-- ============================================================================
-- Function: register_user (PLAINTEXT PASSWORD)
-- ============================================================================
CREATE FUNCTION public.register_user(
    p_username TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_email TEXT DEFAULT NULL,
    p_phone_number TEXT DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
    v_user_id UUID;
    v_result JSON;
BEGIN
    -- Check if username already exists
    IF EXISTS (SELECT 1 FROM public.users WHERE username = p_username) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Username sudah digunakan'
        );
    END IF;
    
    -- Check if email already exists (if provided)
    IF p_email IS NOT NULL AND p_email != '' THEN
        IF EXISTS (SELECT 1 FROM public.users WHERE email = p_email) THEN
            RETURN json_build_object(
                'success', false,
                'error', 'Email sudah terdaftar'
            );
        END IF;
    END IF;
    
    -- Insert new user (PLAINTEXT PASSWORD - DEMO ONLY!)
    INSERT INTO public.users (
        username,
        password,
        full_name,
        email,
        phone_number,
        role
    ) VALUES (
        p_username,
        p_password,
        p_full_name,
        NULLIF(p_email, ''),
        NULLIF(p_phone_number, ''),
        'user'
    ) RETURNING id INTO v_user_id;
    
    -- Return success with user data
    SELECT json_build_object(
        'success', true,
        'user', row_to_json(u.*)
    ) INTO v_result
    FROM public.users u
    WHERE u.id = v_user_id;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- Function: login_user (PLAINTEXT PASSWORD)
-- ============================================================================
CREATE FUNCTION public.login_user(
    p_username TEXT,
    p_password TEXT
) RETURNS JSON AS $$
DECLARE
    v_user_record RECORD;
    v_result JSON;
BEGIN
    -- Find user by username
    SELECT * INTO v_user_record
    FROM public.users
    WHERE username = p_username;
    
    -- User not found
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Username atau password salah'
        );
    END IF;
    
    -- Check if user is banned
    IF v_user_record.is_banned THEN
        RETURN json_build_object(
            'success', false,
            'error', 'ACCOUNT_BANNED'
        );
    END IF;
    
    -- Verify password (PLAINTEXT COMPARISON - DEMO ONLY!)
    IF v_user_record.password != p_password THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Username atau password salah'
        );
    END IF;
    
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

-- ============================================================================
-- Test the functions
-- ============================================================================
SELECT public.register_user('testuser', 'test123', 'Test User', 'test@example.com', '081234567890');
SELECT public.login_user('testuser', 'test123');

-- ============================================================================
-- DONE! Functions updated to use plaintext password
-- ============================================================================
