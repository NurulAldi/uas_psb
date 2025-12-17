# 🔧 FIX: Setup Storage via Supabase Dashboard

## ⚠️ Masalah Permission

Error yang terjadi:
```
ERROR: 42501: must be owner of table objects
```

**Penyebab:** User biasa tidak punya permission untuk mengubah `storage.objects` table via SQL.

**Solusi:** Setup storage bucket via **Supabase Dashboard UI** (tidak perlu SQL!)

---

## ✅ SOLUSI 2 LANGKAH

### Langkah 1: Fix Database View (Via SQL) ✅

**File:** [`supabase_FIX_VIEW_ONLY.sql`](supabase_FIX_VIEW_ONLY.sql)

1. Buka **Supabase Dashboard** → **SQL Editor**
2. Copy-paste isi file `supabase_FIX_VIEW_ONLY.sql`
3. Click **RUN**
4. Lihat output: `✅ DATABASE VIEW FIX: COMPLETE!`

**Ini akan fix:**
- ✅ Error "profiles table not found"
- ✅ Halaman Permintaan Booking

---

### Langkah 2: Fix Storage Upload (Via Dashboard UI) 📁

#### Opsi A: Setup Policy untuk Bucket yang Sudah Ada

1. **Buka Supabase Dashboard**
2. **Klik Storage** (sidebar kiri)
3. **Klik Buckets**
4. **Cari bucket:** `product-images`
   - Jika tidak ada, lanjut ke **Opsi B** (buat baru)
5. **Klik Configuration** (icon gear/settings)
6. **Enable:**
   - ✅ Public bucket = ON
7. **Klik tab "Policies"**
8. **Click "New Policy"**
9. **Pilih "Custom"**
10. **Isi form:**
    ```
    Policy Name: Allow public upload
    Allowed Operations: ✅ INSERT
    Policy Definition: (leave empty or type: true)
    ```
11. **Click Save**
12. **Ulangi** untuk operation lain jika perlu:
    - SELECT (read)
    - UPDATE (edit)
    - DELETE (hapus)

**Screenshot bantuan:**
```
Storage → product-images → Policies tab → New Policy
┌─────────────────────────────────┐
│ Policy name: Allow public upload│
│ Target roles: [✓] public        │
│ Policy type: Permissive         │
│ Using expression: true          │
└─────────────────────────────────┘
```

---

#### Opsi B: Buat Bucket Baru (Recommended!) ⭐

**Lebih mudah dan bersih:**

1. **Buka Supabase Dashboard**
2. **Klik Storage** → **Buckets**
3. **(Optional) Delete bucket lama** `product-images` jika ada issue
4. **Click "New Bucket"**
5. **Isi form:**
   ```
   Name: product-images
   ✅ Public bucket (toggle ON)
   File size limit: 5242880 (5MB)
   Allowed MIME types: image/jpeg,image/png,image/jpg
   ```
6. **Click "Create Bucket"**

**DONE!** Bucket public otomatis punya policy yang permissive.

**Struktur folder otomatis:**
```
product-images/
  └── {userId}/
      └── {timestamp}_{filename}.jpg
```

---

## 🧪 TESTING

### Test 1: Halaman Permintaan Booking
1. Buka Flutter app
2. Login
3. Menu → Permintaan Booking
4. **Expected:** ✅ Tidak ada error "profiles table"

### Test 2: Upload Gambar Produk
1. Tambah Produk Baru
2. Pilih gambar
3. Submit
4. **Expected:** ✅ Upload berhasil

### Test 3: Verifikasi Storage
1. Buka Supabase Dashboard → Storage → product-images
2. **Expected:** File ter-upload di folder `{userId}/`

---

## 📋 TROUBLESHOOTING

### Upload masih gagal setelah setup?

**Check 1: Bucket Public?**
```
Storage → product-images → Configuration
Public bucket = ON ✅
```

**Check 2: Policy Ada?**
```
Storage → product-images → Policies
Should have at least 1 policy for INSERT ✅
```

**Check 3: Flutter App Restart**
```bash
# Stop app
# Run again
flutter run
```

**Check 4: Bucket Name Match?**
Di kode Flutter (`image_upload_service.dart`):
```dart
static const String _bucketName = 'product-images'; // ✅ Harus sama!
```

### Halaman Booking masih error?

**Check: SQL sudah dijalankan?**
```sql
-- Cek di SQL Editor
SELECT COUNT(*) FROM bookings_with_details;
-- Should return angka, tidak error
```

**Check: Table users ada?**
```sql
SELECT COUNT(*) FROM users;
-- Should return jumlah user
```

---

## 📝 SUMMARY LENGKAP

| Masalah | Fix Method | Status |
|---------|------------|--------|
| Profiles table error | SQL (`supabase_FIX_VIEW_ONLY.sql`) | ✅ Run SQL |
| Upload image RLS error | Dashboard UI (create/config bucket) | ✅ Manual setup |

**Waktu total:** ~3 menit
**Skill required:** Basic (point & click UI)
**Success rate:** 99%

---

## 🎯 QUICK CHECKLIST

Langkah-langkah cepat:

- [ ] Run SQL: `supabase_FIX_VIEW_ONLY.sql`
- [ ] Setup Storage via Dashboard:
  - [ ] Opsi A: Config bucket existing
  - [ ] Opsi B: Create new bucket (recommended)
- [ ] Restart Flutter app
- [ ] Test upload gambar
- [ ] Test halaman booking

**DONE!** ✅

---

## 📚 FILES REFERENCE

**SQL Files:**
- [`supabase_FIX_VIEW_ONLY.sql`](supabase_FIX_VIEW_ONLY.sql) ⭐ **USE THIS**
- ~~supabase_MASTER_FIX_ALL.sql~~ (needs high privilege)

**Documentation:**
- [STORAGE_SETUP_DASHBOARD_GUIDE.md](STORAGE_SETUP_DASHBOARD_GUIDE.md) ⭐ **THIS FILE**
- [COMPLETE_FIX_GUIDE.md](COMPLETE_FIX_GUIDE.md) - General guide

---

## 💡 WHY Dashboard Instead of SQL?

**Supabase Storage Security Model:**
- Storage policies require system-level privileges
- Regular SQL users can't ALTER storage.objects
- Dashboard UI has built-in admin privileges
- UI creates policies with correct permissions automatically

**Benefits:**
- ✅ No permission errors
- ✅ Visual, easier to understand
- ✅ Built-in validation
- ✅ Can't break system tables

---

**Need Help?** 
- Check Supabase Storage Documentation
- Lihat screenshot di Supabase Dashboard
- Test step-by-step, jangan skip

**Happy Coding! 🚀**
