# 🔧 Panduan Fix Error admin_banned_users_view

## ❌ Error yang Terjadi
```
PostgrestException(message: Could not find the table 'public.admin_banned_users_view' 
in the schema cache, code: PGRST205)
```

Error ini terjadi karena view `admin_banned_users_view` belum dibuat di database Supabase Anda.

## ✅ Solusi

### Langkah 1: Buka Supabase Dashboard
1. Pergi ke [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Pilih project RentLens Anda
3. Klik menu **SQL Editor** di sidebar kiri

### Langkah 2: Jalankan Script SQL
1. Buat query baru (klik **New Query**)
2. Copy seluruh isi file `supabase_CREATE_BANNED_USERS_VIEW.sql`
3. Paste ke SQL Editor
4. Klik tombol **Run** atau tekan `Ctrl + Enter`

### Langkah 3: Verifikasi
Setelah script berhasil dijalankan, Anda akan melihat:
- ✅ Kolom-kolom ban ditambahkan ke tabel `profiles`
- ✅ View `admin_banned_users_view` berhasil dibuat
- ✅ Test query menampilkan hasil (kosong jika belum ada user yang di-ban)

### Langkah 4: Test di Aplikasi
1. Restart aplikasi Flutter Anda
2. Login sebagai admin
3. Coba ban satu user
4. Error seharusnya sudah hilang ✅

## 📋 Yang Dilakukan oleh Script

Script akan:
1. **Menambahkan kolom ke tabel profiles:**
   - `is_banned` - Boolean untuk status banned
   - `banned_at` - Timestamp kapan di-ban
   - `banned_by` - ID admin yang melakukan ban
   - `ban_reason` - Alasan kenapa di-ban

2. **Membuat view `admin_banned_users_view`:**
   - Menampilkan daftar user yang di-ban
   - Info admin yang melakukan ban
   - Statistik user (products, bookings, reports)

3. **Set permissions:**
   - Memberikan akses SELECT ke authenticated users

## 🎯 Hasil Akhir

Setelah menjalankan script, fitur ban user akan berfungsi normal:
- Admin bisa ban user dengan alasan
- Admin bisa lihat daftar banned users
- Admin bisa unban user
- Semua informasi tersimpan dengan benar

## ⚠️ Catatan Penting

- Script menggunakan `IF NOT EXISTS` jadi aman dijalankan berulang kali
- Tidak akan menghapus data yang sudah ada
- Jika ada error, periksa apakah tabel `profiles` ada di database

## 🐛 Troubleshooting

### Error: relation "profiles" does not exist
Jalankan dulu migration utama:
```sql
-- Lihat file: supabase_admin_features_FINAL.sql
```

### Error: permission denied
Pastikan Anda menjalankan script sebagai user yang punya akses admin di Supabase.

### View masih tidak terdeteksi
1. Refresh schema cache: `NOTIFY pgrst, 'reload schema'`
2. Atau restart Supabase project dari dashboard
