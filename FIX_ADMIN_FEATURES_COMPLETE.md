# 🔧 PANDUAN FIX ERROR ADMIN FEATURES

## ❌ Error yang Terjadi

### 1. Ban User Tidak Ada Feedback
Ketika ban user, tidak ada output di console dan tidak ada yang terjadi di UI.

### 2. Error admin_reports_view
```
PostgrestException(message: Could not find the table 'public.admin_reports_view' 
in the schema cache, code: PGRST205)
```

## 🎯 Penyebab Masalah

1. **View admin_reports_view belum dibuat** di database
2. **View admin_banned_users_view menggunakan tabel yang salah** (`profiles` bukan `users`)
3. **Function ban/unban tidak memberikan feedback** yang jelas
4. **Tidak ada SQL function** untuk ban/unban, hanya direct UPDATE query

## ✅ SOLUSI LENGKAP

### 📋 Langkah 1: Jalankan Script SQL

1. Buka **Supabase Dashboard** → https://supabase.com/dashboard
2. Pilih project **RentLens** Anda
3. Klik menu **SQL Editor** di sidebar kiri
4. Buat **New Query**
5. Copy **SEMUA ISI** dari file `supabase_ADMIN_VIEWS_FUNCTIONS_FIX.sql`
6. Paste ke SQL Editor
7. Klik **Run** atau tekan `Ctrl + Enter`

### 🔍 Apa yang Dilakukan Script?

Script akan membuat:

#### 1. View `admin_reports_view` ✅
- Menampilkan semua laporan dengan info lengkap
- Info pelapor (reporter)
- Info user yang dilaporkan
- Info produk yang dilaporkan
- Info admin yang mereview
- **MENGGUNAKAN TABEL `users` BUKAN `profiles`**

#### 2. View `admin_stats_view` ✅
- Statistik total users, admins, banned users
- Statistik produk (total, active, rented)
- Statistik booking (pending, confirmed, active, completed)
- Statistik laporan (pending, reviewing, resolved)
- Statistik revenue

#### 3. Function `admin_ban_user()` ✅
- Ban user dengan validasi lengkap
- Cek apakah user exists
- Cek apakah yang ban adalah admin
- Cek apakah user sudah di-ban
- Return JSON dengan success/error message
- **MEMBERIKAN FEEDBACK YANG JELAS**

#### 4. Function `admin_unban_user()` ✅
- Unban user dengan validasi
- Cek apakah user exists
- Cek apakah user memang dalam status banned
- Return JSON dengan success/error message
- **MEMBERIKAN FEEDBACK YANG JELAS**

### 🔄 Langkah 2: Restart Aplikasi Flutter

```bash
# Stop aplikasi yang sedang berjalan (Ctrl + C di terminal)
# Lalu jalankan lagi
flutter run
```

### 🧪 Langkah 3: Test Fitur Ban User

1. **Login sebagai admin**
   - Username: `admin`
   - Password: `admin123`

2. **Pergi ke halaman Users Management**

3. **Coba ban satu user**
   - Klik tombol "Ban" pada user
   - Isi alasan ban
   - Klik "Ban"

4. **Cek Console Output**
   Sekarang Anda akan melihat output seperti:
   ```
   🔨 Attempting to ban user...
      User ID: xxx-xxx-xxx
      Admin ID: xxx-xxx-xxx
      Reason: Melanggar aturan
   📥 Response from ban function: {success: true, message: User berhasil di-ban, ...}
   ✅ User banned successfully!
   ```

5. **Cek UI**
   - Akan muncul SnackBar "User berhasil di-ban"
   - User akan pindah ke tab "Banned Users"
   - Data akan refresh otomatis

### 📊 Langkah 4: Test Halaman Reports

1. **Pergi ke halaman Reports**
2. **Error seharusnya sudah hilang** ✅
3. Anda akan melihat daftar laporan (jika ada)

## 🔥 Yang Berubah di Code Flutter

### admin_repository.dart

**SEBELUM:**
```dart
// Direct UPDATE query - tidak ada feedback
await _supabase.from('users').update({
  'is_banned': true,
  'banned_at': DateTime.now().toIso8601String(),
  'banned_by': adminId,
  'ban_reason': reason,
}).eq('id', userId);
```

**SESUDAH:**
```dart
// Call SQL function - dengan feedback lengkap
final response = await _supabase.rpc(
  'admin_ban_user',
  params: {
    'p_user_id': userId,
    'p_admin_id': adminId,
    'p_reason': reason,
  },
);

print('📥 Response: $response');
```

## 📝 Verifikasi

Setelah menjalankan script, verifikasi dengan query ini di SQL Editor:

```sql
-- Cek view reports
SELECT * FROM admin_reports_view LIMIT 1;

-- Cek view banned users
SELECT * FROM admin_banned_users_view LIMIT 1;

-- Cek view stats
SELECT * FROM admin_stats_view;

-- Test function ban (ganti UUID dengan user ID yang valid)
SELECT admin_ban_user(
  'user-uuid-here'::UUID,
  'admin-uuid-here'::UUID,
  'Test ban'
);

-- Test function unban
SELECT admin_unban_user('user-uuid-here'::UUID);
```

## ⚠️ Troubleshooting

### Error: function admin_ban_user does not exist
**Solusi:** Jalankan ulang script `supabase_ADMIN_VIEWS_FUNCTIONS_FIX.sql`

### Error: relation "users" does not exist
**Solusi:** Pastikan Anda sudah menjalankan `supabase_manual_auth_migration.sql` terlebih dahulu

### Ban user masih tidak ada feedback
**Solusi:** 
1. Cek apakah function sudah dibuat di Supabase
2. Restart aplikasi Flutter
3. Clear cache: `flutter clean && flutter pub get`

### Error: column "profiles" does not exist
**Solusi:** Script sudah menggunakan tabel `users`. Pastikan Anda menjalankan script terbaru.

## 🎉 Hasil Akhir

Setelah semua langkah selesai:

- ✅ Ban user memberikan feedback di console
- ✅ Ban user memberikan feedback di UI (SnackBar)
- ✅ Halaman Reports tidak error lagi
- ✅ View banned users berfungsi
- ✅ Statistics dashboard lengkap
- ✅ Unban user juga berfungsi dengan feedback

## 📚 File-file Terkait

1. `supabase_ADMIN_VIEWS_FUNCTIONS_FIX.sql` - Script SQL utama
2. `supabase_CREATE_BANNED_USERS_VIEW.sql` - View banned users (sudah termasuk di script utama)
3. `lib/features/admin/data/admin_repository.dart` - Sudah diupdate
4. `supabase_manual_auth_migration.sql` - Tabel users (prerequisite)

## 🚀 Quick Start

Intinya, cukup jalankan **2 langkah**:

1. **Jalankan SQL:**
   - Buka Supabase SQL Editor
   - Copy-paste `supabase_ADMIN_VIEWS_FUNCTIONS_FIX.sql`
   - Run

2. **Restart Flutter:**
   ```bash
   flutter run
   ```

Done! 🎉
