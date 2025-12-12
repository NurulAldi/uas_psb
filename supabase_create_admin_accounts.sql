-- =====================================================
-- Script: Create Admin Accounts in Profiles Table
-- Description: Insert admin users into profiles table
-- Date: 2025-12-12
-- =====================================================

-- Option 1: Upgrade existing user to admin
-- Mengubah user yang sudah ada menjadi admin
-- UPDATE profiles
-- SET 
--   role = 'admin',
--   updated_at = NOW()
-- WHERE email = 'aldiscreamo32@gmail.com';

-- Option 2: Insert new admin account manually
-- Untuk membuat akun admin baru, pastikan akun sudah terdaftar di Supabase Auth terlebih dahulu
-- Kemudian jalankan query ini dengan ID yang sesuai

-- Example: Insert admin account (ganti dengan data sebenarnya)
INSERT INTO profiles (
  id,
  email,
  full_name,
  phone_number,
  role,
  is_banned,
  created_at,
  updated_at
) VALUES (
  '00000000-0000-0000-0000-000000000001', -- Ganti dengan UUID dari Supabase Auth
  'admin@rentlens.com',
  'Admin RentLens',
  '081234567890',
  'admin',
  false,
  NOW(),
  NOW()
);

-- Option 3: Upgrade multiple users to admin at once
-- UPDATE profiles
-- SET 
--   role = 'admin',
--   updated_at = NOW()
-- WHERE email IN (
--   'aldiscreamo32@gmail.com',
--   'aldiprm48@gmail.com'
-- );

-- Verify admin accounts
SELECT 
  id,
  email,
  full_name,
  role,
  is_banned,
  created_at,
  updated_at
FROM profiles
WHERE role = 'admin'
ORDER BY created_at DESC;

-- =====================================================
-- CARA PENGGUNAAN:
-- =====================================================
-- 1. Untuk upgrade user existing menjadi admin:
--    - Uncomment Option 1 dan jalankan
--    - Ganti email dengan email user yang ingin dijadikan admin
--
-- 2. Untuk membuat admin baru dari scratch:
--    - Daftar akun baru melalui aplikasi atau Supabase Auth
--    - Copy UUID dari auth.users
--    - Uncomment Option 2 dan isi data admin
--    - Jalankan query
--
-- 3. Untuk upgrade banyak user sekaligus:
--    - Uncomment Option 3
--    - Tambahkan email-email yang ingin dijadikan admin
--    - Jalankan query
-- =====================================================
