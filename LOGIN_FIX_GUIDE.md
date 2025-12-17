# 🔐 Login Issue Fix - Password Hash Mismatch

## 🔴 Problem

Login gagal dengan error **"Username atau password salah"** meskipun menggunakan credentials yang benar.

### Root Cause

Password hash di database menggunakan placeholder string (`admin123hash`, `password123hash`), sedangkan Flutter menggunakan **SHA-256 hashing**.

**Contoh Mismatch:**
```sql
-- ❌ SALAH (di database lama)
password_hash = 'admin123hash'

-- ✅ BENAR (SHA-256 hash dari 'admin123')
password_hash = '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9'
```

## ✅ Solution

### Step 1: Update Password Hashes di Database

Buka **Supabase Dashboard** → **SQL Editor** → Jalankan query berikut:

```sql
-- Update admin account
UPDATE public.users 
SET password_hash = '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9' 
WHERE username = 'admin';

-- Update regular users
UPDATE public.users 
SET password_hash = 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f' 
WHERE username IN ('user1', 'user2');

-- Update demo account
UPDATE public.users 
SET password_hash = 'd3ad9315b7be5dd53b31a273b3b3aba5defe700808305aa16a3062b76658a791' 
WHERE username = 'demo';
```

**Atau gunakan file SQL yang sudah disediakan:**
- File: `supabase_FIX_PASSWORD_HASHES.sql`
- Copy semua isi file → paste ke Supabase SQL Editor → Run

### Step 2: Verify Update Berhasil

```sql
SELECT 
    username, 
    full_name, 
    CASE 
        WHEN password_hash = '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9' THEN '✓ admin123'
        WHEN password_hash = 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f' THEN '✓ password123'
        WHEN password_hash = 'd3ad9315b7be5dd53b31a273b3b3aba5defe700808305aa16a3062b76658a791' THEN '✓ demo123'
        ELSE '✗ Invalid'
    END as password_status
FROM public.users
WHERE username IN ('admin', 'user1', 'user2', 'demo');
```

**Expected Output:**
```
username | full_name      | password_status
---------|----------------|----------------
admin    | Administrator  | ✓ admin123
demo     | Demo Account   | ✓ demo123
user1    | Demo User 1    | ✓ password123
user2    | Demo User 2    | ✓ password123
```

### Step 3: Test Login di Flutter

Gunakan credentials berikut:

| Username | Password     | Role  |
|----------|--------------|-------|
| `admin`  | `admin123`   | admin |
| `user1`  | `password123`| user  |
| `user2`  | `password123`| user  |
| `demo`   | `demo123`    | user  |

## 🔍 How Password Validation Works

### Flutter Side (auth_repository.dart)

```dart
// 1. User inputs password in plain text
final password = 'admin123';

// 2. Flutter hashes with SHA-256
final passwordHash = PasswordHelper.hashPassword(password);
// Result: '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9'

// 3. Call PostgreSQL function
await _supabase.rpc('login_user', params: {
  'p_username': 'admin',
  'p_password_hash': passwordHash, // Send hash, not plain text
});
```

### Database Side (login_user function)

```sql
-- 1. Receive hashed password from Flutter
CREATE FUNCTION login_user(p_username TEXT, p_password_hash TEXT)

-- 2. Find user in database
SELECT * FROM users WHERE username = p_username;

-- 3. Compare hash from Flutter with hash in database
IF v_user_record.password_hash != p_password_hash THEN
    RETURN json_build_object('success', false, 'error', 'Username atau password salah');
END IF;
```

### Password Hash Generation

**Flutter uses:**
```dart
import 'package:crypto/crypto.dart';
import 'dart:convert';

String hashPassword(String password) {
  final bytes = utf8.encode(password);
  final hash = sha256.convert(bytes);
  return hash.toString();
}
```

**SHA-256 Hashes:**
```
'admin123'      -> '240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9'
'password123'   -> 'ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f'
'demo123'       -> 'd3ad9315b7be5dd53b31a273b3b3aba5defe700808305aa16a3062b76658a791'
```

## 🛠️ For Future Account Creation

Jika membuat user baru, gunakan hash yang benar:

```sql
-- Generate hash di Flutter first:
-- dart generate_hashes.dart

-- Then insert with correct hash:
INSERT INTO public.users (username, password_hash, full_name, email, role)
VALUES (
    'newuser', 
    'SHA256_HASH_HERE',  -- Replace with actual hash
    'New User', 
    'newuser@example.com', 
    'user'
);
```

## 📋 Checklist

- [x] Generate SHA-256 hashes untuk demo passwords
- [x] Update `supabase_manual_auth_migration.sql` dengan hash yang benar
- [x] Buat `supabase_FIX_PASSWORD_HASHES.sql` untuk update database existing
- [ ] **Jalankan SQL update di Supabase Dashboard**
- [ ] Verify password hashes sudah benar
- [ ] Test login dengan credentials demo

## 🎯 Next Steps

1. **Segera jalankan** `supabase_FIX_PASSWORD_HASHES.sql` di Supabase SQL Editor
2. Test login dengan username: `admin`, password: `admin123`
3. Jika masih gagal, cek console Flutter untuk error message lengkap
4. Verify bahwa `login_user` function ada di database

## 🔗 Related Files

- `supabase_FIX_PASSWORD_HASHES.sql` - SQL untuk fix password hashes
- `generate_hashes.dart` - Script untuk generate SHA-256 hash
- `lib/core/utils/password_helper.dart` - Password hashing implementation
- `lib/features/auth/data/repositories/auth_repository.dart` - Login logic
