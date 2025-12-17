# ⚠️ PLAINTEXT PASSWORD - QUICK FIX GUIDE

## 🎯 Tujuan
Ubah sistem authentication dari password hash ke plaintext untuk kemudahan demo/academic.

## ✅ Yang Sudah Diubah

### 1. Database Schema
- Kolom `password_hash` → `password` (plaintext)
- Function `login_user()` compare plaintext
- Function `register_user()` save plaintext

### 2. Flutter Code
- `auth_repository.dart` tidak lagi hash password
- Kirim password langsung ke database

## 🚀 Cara Apply

### Step 1: Update Database Structure
Buka **Supabase Dashboard** → **SQL Editor** → Run:

```sql
-- Rename column
ALTER TABLE public.users 
RENAME COLUMN password_hash TO password;

-- Convert existing accounts
UPDATE public.users SET password = 'admin123' WHERE username = 'admin';
UPDATE public.users SET password = 'password123' WHERE username IN ('user1', 'user2');
UPDATE public.users SET password = 'demo123' WHERE username = 'demo';
```

**ATAU** copy paste semua isi file `supabase_CONVERT_TO_PLAINTEXT.sql`

### Step 2: Update Functions
Run file `supabase_manual_auth_migration.sql` yang sudah diupdate.

**ATAU** manual update functions:

```sql
-- Update login function
CREATE OR REPLACE FUNCTION public.login_user(
    p_username TEXT,
    p_password TEXT  -- Changed from p_password_hash
) RETURNS JSON AS $$
DECLARE
    v_user_record RECORD;
    v_result JSON;
BEGIN
    SELECT * INTO v_user_record FROM public.users WHERE username = p_username;
    
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Username atau password salah');
    END IF;
    
    IF v_user_record.is_banned THEN
        RETURN json_build_object('success', false, 'error', 'ACCOUNT_BANNED');
    END IF;
    
    -- Plaintext comparison
    IF v_user_record.password != p_password THEN
        RETURN json_build_object('success', false, 'error', 'Username atau password salah');
    END IF;
    
    UPDATE public.users SET last_login_at = NOW() WHERE id = v_user_record.id;
    
    SELECT json_build_object('success', true, 'user', row_to_json(v_user_record)) INTO v_result;
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update register function
CREATE OR REPLACE FUNCTION public.register_user(
    p_username TEXT,
    p_password TEXT,  -- Changed from p_password_hash
    p_full_name TEXT,
    p_email TEXT DEFAULT NULL,
    p_phone_number TEXT DEFAULT NULL
) RETURNS JSON AS $$
-- ... (similar changes)
```

### Step 3: Hot Restart Flutter
```bash
# Tekan R (shift+r) di terminal flutter run
# Atau restart app
```

## 🎮 Test Login

| Username | Password | Role |
|----------|----------|------|
| admin | admin123 | admin |
| user1 | password123 | user |
| demo | demo123 | user |

## 📝 Membuat Akun Baru

Sekarang GAMPANG banget! Langsung INSERT plaintext:

```sql
INSERT INTO public.users (username, password, full_name, email, role)
VALUES ('newuser', 'mypassword', 'New User', 'new@example.com', 'user');
```

Login langsung pakai:
- Username: `newuser`
- Password: `mypassword`

DONE! ✅

## ⚠️ SECURITY WARNING

**JANGAN PERNAH PAKAI INI DI PRODUCTION!**

Plaintext password = semua orang yang akses database bisa lihat password semua user.

Tapi untuk demo/academic/presentation = **PERFECT!** 👍
- Gampang testing
- Gampang bikin akun baru
- Gampang debugging
- No hassle with hashing

## 🔗 Files Modified

- ✅ `supabase_manual_auth_migration.sql` - Schema & functions updated
- ✅ `supabase_CONVERT_TO_PLAINTEXT.sql` - Conversion script
- ✅ `lib/features/auth/data/repositories/auth_repository.dart` - No more hashing
