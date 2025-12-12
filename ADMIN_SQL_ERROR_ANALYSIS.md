# 🔍 Analisis Error Script SQL Admin

## ❌ Error Utama
```
ERROR: 42P01: relation "public.users" does not exist
```

## 📊 Root Cause Analysis

### 1. **Kesalahan Nama Table** ❌

**Salah:**
```sql
public.users
```

**Benar:**
```sql
public.profiles
```

**Bukti:**
- File `supabase_setup.sql` line 21: `CREATE TABLE IF NOT EXISTS profiles`
- Semua script lain (location, delivery, payment) menggunakan `profiles`
- Table `users` hanya ada di schema `auth.users` (Supabase Auth), bukan `public.users`

---

## 🐛 Daftar Lengkap Kesalahan di `supabase_admin_features.sql`

### Error #1: Reference ke Table yang Salah
**Lokasi:** Line 38, 43, 46
```sql
❌ ALTER TABLE public.users 
✅ ALTER TABLE public.profiles
```

### Error #2: Foreign Key References
**Lokasi:** Line 62, 63
```sql
❌ reporter_id UUID NOT NULL REFERENCES public.users(id)
❌ reported_user_id UUID REFERENCES public.users(id)
✅ reporter_id UUID NOT NULL REFERENCES public.profiles(id)
✅ reported_user_id UUID REFERENCES public.profiles(id)
```

### Error #3: Policy Checks
**Lokasi:** Line 142-148
```sql
❌ SELECT 1 FROM public.users
   WHERE id = auth.uid() AND is_banned = TRUE
✅ SELECT 1 FROM public.profiles
   WHERE id = auth.uid() AND is_banned = TRUE
```

### Error #4: View Definitions
**Lokasi:** Line 211-226
```sql
❌ INNER JOIN public.users reporter ON r.reporter_id = reporter.id
❌ LEFT JOIN public.users reported_user ON r.reported_user_id = reported_user.id
✅ INNER JOIN public.profiles reporter ON r.reporter_id = reporter.id
✅ LEFT JOIN public.profiles reported_user ON r.reported_user_id = reported_user.id
```

### Error #5: Banned Users View
**Lokasi:** Line 230-248
```sql
❌ FROM public.users u
✅ FROM public.profiles u
```

### Error #6: Kolom yang Berbeda
**Masalah:** Script menggunakan nama kolom yang tidak ada

| Script Admin (❌) | Table Profiles (✅) |
|------------------|-------------------|
| `phone` | `phone_number` |
| Tidak ada `renter_id` | `user_id` |

---

## 🔧 Perbaikan yang Diperlukan

### 1. Ganti Semua `public.users` → `public.profiles`
Total: **12 lokasi** yang harus diganti

### 2. Sesuaikan Nama Kolom
- Line 241: `u.phone` → `u.phone_number`
- Cek kolom bookings: `renter_id` tidak ada, yang ada `user_id`

### 3. Hapus/Modifikasi Table `admins`
**Pertimbangan:**
- Supabase sudah punya auth system
- Table profiles sudah punya kolom `role` (dari script rbac)
- Lebih baik pakai profiles dengan role='admin'

**Rekomendasi:**
```sql
-- Gunakan role di profiles
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user'
  CHECK (role IN ('user', 'admin'));

-- Check admin via role
WHERE role = 'admin'
```

### 4. Struktur Table Profiles yang Benar

Dari `supabase_setup.sql` dan migration lainnya:
```sql
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    phone_number TEXT,
    avatar_url TEXT,
    
    -- Dari location feature
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address TEXT,
    city TEXT,
    location_updated_at TIMESTAMPTZ,
    
    -- Dari RBAC
    role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin')),
    is_banned BOOLEAN DEFAULT FALSE,
    banned_at TIMESTAMPTZ,
    banned_by UUID REFERENCES profiles(id),
    ban_reason TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 5. Table Bookings yang Benar
```sql
CREATE TABLE bookings (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES profiles(id),  -- ✅ user_id, bukan renter_id
    product_id UUID REFERENCES products(id),
    owner_id UUID REFERENCES profiles(id),
    -- ... columns lain
);
```

---

## 📝 Checklist Perbaikan

### Immediate Fixes (Wajib):
- [ ] Ganti semua `public.users` → `public.profiles` (12x)
- [ ] Ganti `phone` → `phone_number` (1x)
- [ ] Pastikan kolom `is_banned` sudah ada di profiles
- [ ] Hapus/modifikasi table `admins` (gunakan role di profiles)

### Recommended Fixes:
- [ ] Gunakan `role` kolom untuk admin check, bukan table terpisah
- [ ] Update policy untuk check `role = 'admin'`
- [ ] Sesuaikan view dengan kolom yang benar
- [ ] Test semua policy setelah fix

### Schema Verification:
- [ ] Cek `profiles` table sudah punya kolom: `role`, `is_banned`
- [ ] Cek `bookings` table pakai `user_id` bukan `renter_id`
- [ ] Verify foreign key references

---

## 💡 Solusi Alternatif untuk Admin

### Option 1: Gunakan Role di Profiles (Recommended ✅)
```sql
-- Check if user is admin
WHERE EXISTS (
  SELECT 1 FROM profiles 
  WHERE id = auth.uid() 
  AND role = 'admin'
)
```

**Pros:**
- Konsisten dengan struktur yang ada
- Tidak perlu table terpisah
- Lebih sederhana
- Auth tetap via Supabase Auth

### Option 2: Table Admins Terpisah (Current - Not Recommended ❌)
**Cons:**
- Duplikasi data
- Kompleks password management
- Tidak terintegrasi dengan Supabase Auth
- Perlu custom login flow

---

## 🚀 Quick Fix Script

Jalankan ini SEBELUM script admin:

```sql
-- 1. Pastikan profiles punya role dan is_banned
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user' 
  CHECK (role IN ('user', 'admin'));

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE;

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS banned_at TIMESTAMPTZ;

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS banned_by UUID REFERENCES profiles(id);

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS ban_reason TEXT;

-- 2. Create admin user (gunakan user yang sudah signup)
UPDATE profiles 
SET role = 'admin' 
WHERE email = 'admin@rentlens.com';
```

---

## 📌 Summary

### Critical Issues:
1. ❌ **Table Name Error**: `users` → `profiles` (12 occurrences)
2. ❌ **Column Name Error**: `phone` → `phone_number`
3. ❌ **Architecture Issue**: Separate admins table tidak diperlukan

### Recommended Approach:
1. ✅ Gunakan `profiles.role` untuk distinguish admin
2. ✅ Update semua references ke table yang benar
3. ✅ Simplify admin authentication
4. ✅ Test semua RLS policies

### Files to Update:
- `supabase_admin_features.sql` - Major rewrite needed
- Test dengan `supabase_rbac_and_reporting.sql` - Sudah correct

---

**Priority**: 🔴 CRITICAL - Script tidak akan jalan tanpa fix ini
**Impact**: All admin features broken
**Effort**: Medium (1-2 hours untuk rewrite)
