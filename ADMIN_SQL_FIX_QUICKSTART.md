# 🔧 Quick Fix: Admin SQL Error

## ❌ Problem
```
ERROR: 42P01: relation "public.users" does not exist
```

## ✅ Solution
Table yang benar adalah **`profiles`** bukan `users`!

---

## 📝 Kesalahan di Script Original

### 1. **Nama Table Salah (12 tempat)**
```sql
❌ public.users
✅ public.profiles
```

### 2. **Nama Kolom Salah**
```sql
❌ phone
✅ phone_number
```

### 3. **Architecture Salah**
- ❌ Table `admins` terpisah dengan password hash
- ✅ Pakai kolom `role` di table `profiles`

---

## 🚀 Cara Menggunakan Script yang Benar

### Step 1: Gunakan Script Fixed
```bash
# Jangan pakai: supabase_admin_features.sql
# Pakai ini:
supabase_admin_features_FIXED.sql
```

### Step 2: Jalankan di Supabase SQL Editor
1. Buka Supabase Dashboard
2. Go to SQL Editor
3. Copy-paste isi file `supabase_admin_features_FIXED.sql`
4. Click **Run**

### Step 3: Promote User Jadi Admin
```sql
-- Cara 1: Promote user yang sudah signup
UPDATE profiles 
SET role = 'admin' 
WHERE email = 'admin@rentlens.com';

-- Cara 2: Promote by user ID
UPDATE profiles 
SET role = 'admin' 
WHERE id = 'your-user-uuid-here';
```

---

## 🔑 Key Differences

### Original (Broken) ❌
```sql
-- Table terpisah untuk admin
CREATE TABLE admins (
    email TEXT,
    password_hash TEXT  -- Manual password management
);

-- Reference ke table yang salah
REFERENCES public.users(id)  -- ERROR: tidak ada table ini!
```

### Fixed (Working) ✅
```sql
-- Pakai kolom role di profiles
ALTER TABLE profiles 
ADD COLUMN role TEXT DEFAULT 'user' 
CHECK (role IN ('user', 'admin'));

-- Reference yang benar
REFERENCES profiles(id)  -- ✅ Table ini ada!

-- Check admin via role
WHERE EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() 
    AND role = 'admin'
)
```

---

## 📊 Database Schema yang Benar

### Table: profiles
```sql
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    phone_number TEXT,  -- ✅ bukan 'phone'
    avatar_url TEXT,
    
    -- Admin & Ban features
    role TEXT DEFAULT 'user',  -- ✅ 'user' or 'admin'
    is_banned BOOLEAN DEFAULT FALSE,
    banned_at TIMESTAMPTZ,
    banned_by UUID REFERENCES profiles(id),
    ban_reason TEXT,
    
    -- Location features
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address TEXT,
    city TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Table: bookings
```sql
CREATE TABLE bookings (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES profiles(id),  -- ✅ user_id, bukan renter_id
    product_id UUID REFERENCES products(id),
    owner_id UUID REFERENCES profiles(id),
    -- ...
);
```

---

## ✅ Verification Checklist

Setelah run script, verify dengan query ini:

### 1. Check Columns Exist
```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND column_name IN ('role', 'is_banned', 'banned_at', 'banned_by', 'ban_reason');
```

Expected: 5 rows returned

### 2. Check Reports Table
```sql
SELECT * FROM reports LIMIT 1;
```

Expected: Table exists (might be empty)

### 3. Check Views
```sql
SELECT * FROM admin_reports_view LIMIT 1;
SELECT * FROM admin_banned_users_view LIMIT 1;
SELECT * FROM admin_stats_view;
```

Expected: All views exist

### 4. Check Admin User
```sql
SELECT id, email, full_name, role 
FROM profiles 
WHERE role = 'admin';
```

Expected: At least 1 admin user

---

## 🎯 Admin Functions Available

### Ban User
```sql
SELECT ban_user(
    'user-uuid-to-ban',
    'Reason for ban',
    auth.uid()  -- your admin user id
);
```

### Unban User
```sql
SELECT unban_user(
    'user-uuid-to-unban',
    auth.uid()  -- your admin user id
);
```

### Get Stats
```sql
SELECT * FROM admin_stats_view;
```

---

## 🐛 Common Errors & Fixes

### Error: "column role does not exist"
**Fix:** Script belum jalan, run `supabase_admin_features_FIXED.sql`

### Error: "permission denied for table profiles"
**Fix:** Check RLS policies, pastikan user adalah admin

### Error: "function ban_user does not exist"
**Fix:** Script belum lengkap, run ulang dari awal

---

## 📚 Related Files

1. **Use This:**
   - ✅ `supabase_admin_features_FIXED.sql` - Script yang benar

2. **Don't Use:**
   - ❌ `supabase_admin_features.sql` - Script original yang error

3. **Reference:**
   - 📖 `ADMIN_SQL_ERROR_ANALYSIS.md` - Analisis lengkap error
   - 📖 `supabase_setup.sql` - Base schema
   - 📖 `supabase_rbac_and_reporting.sql` - Alternative (sudah benar)

---

## 💡 Pro Tips

1. **Jangan Buat Table Admins Terpisah**
   - Gunakan `role` column di profiles
   - Lebih simple & terintegrasi dengan Supabase Auth

2. **Promote Admin via SQL**
   - Signup normal via app
   - Promote ke admin via SQL
   - No custom password management needed

3. **Check Script Lain**
   - File `supabase_rbac_and_reporting.sql` juga implement admin
   - Pilih salah satu, jangan run both!

---

**Last Updated:** December 12, 2025  
**Status:** ✅ Fixed & Tested
