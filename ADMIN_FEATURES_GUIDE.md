# Admin Features - RentLens

## Overview
Fitur admin untuk RentLens memungkinkan administrator untuk:
- ✅ Ban/Unban pengguna yang melanggar aturan
- ✅ Menerima dan mengelola laporan dari pengguna
- ✅ Melihat statistik platform
- ✅ Monitoring aktivitas pengguna

## Database Setup

### 1. Jalankan Migration SQL
Jalankan file `supabase_admin_features.sql` di Supabase SQL Editor untuk membuat:
- Tabel `admins` - menyimpan akun admin
- Tabel `reports` - menyimpan laporan dari pengguna
- Update tabel `users` dengan kolom `is_banned`, `banned_at`, `banned_by`, `ban_reason`
- Views untuk admin dashboard
- RLS policies untuk keamanan

```sql
-- File: supabase_admin_features.sql
-- Copy dan paste ke Supabase SQL Editor, lalu Execute
```

### 2. Buat Akun Admin
Admin **TIDAK** bisa register melalui aplikasi. Admin harus dibuat manual di database:

```sql
-- Contoh membuat admin
INSERT INTO public.admins (email, password_hash, name)
VALUES (
    'admin@rentlens.com',
    'password_anda',  -- Gunakan password plaintext untuk testing
    'Admin RentLens'
);
```

⚠️ **PENTING untuk Production:**
- Gunakan bcrypt untuk hash password sebelum insert ke database
- Jangan simpan password plaintext
- Update `AdminRepository.authenticateAdmin()` untuk verifikasi bcrypt

## Cara Login sebagai Admin

### Halaman Login yang Sama
Admin dan user biasa menggunakan halaman login yang sama (`/auth/login`).

**Flow Login:**
1. User masukkan email dan password
2. Sistem cek apakah email ada di tabel `admins`
3. Jika YA → Login sebagai admin → Redirect ke `/admin`
4. Jika TIDAK → Login sebagai user biasa → Redirect ke `/`

### Contoh Login Admin
```
Email: admin@rentlens.com
Password: admin123
```

Setelah login, akan otomatis diarahkan ke Admin Dashboard.

## Fitur Admin Dashboard

### 1. Statistics (Dashboard Tab)
Menampilkan overview platform:
- Total Users
- Banned Users
- Pending Reports (yang belum direview)
- Total Reports
- Total Products
- Total Bookings

**Cara akses:**
- Login sebagai admin
- Tab pertama di Admin Dashboard

### 2. User Management (Users Tab)

#### Tab: All Users
Melihat semua pengguna terdaftar dengan informasi:
- Nama lengkap
- Email
- Nomor telepon
- Status (Banned/Active)
- Tombol Ban untuk user aktif

**Cara Ban User:**
1. Klik icon Block (🚫) pada card user
2. Masukkan alasan ban
3. Konfirmasi
4. User akan di-ban dan tidak bisa login

#### Tab: Banned Users
Melihat daftar user yang sudah di-ban dengan detail:
- Info user (email, phone)
- Jumlah produk user
- Jumlah booking user
- Jumlah laporan terhadap user
- Admin yang melakukan ban
- Alasan ban
- Tombol Unban

**Cara Unban User:**
1. Expand card user yang di-ban
2. Klik tombol "Unban User"
3. Konfirmasi
4. User bisa login kembali

### 3. Reports Management (Reports Tab)

#### Tab: Pending Reports
Laporan yang belum direview admin.

**Informasi Report:**
- Tipe laporan (User/Product)
- Reporter (siapa yang melapor)
- Target laporan (user/product yang dilaporkan)
- Alasan laporan
- Deskripsi detail (opsional)
- Waktu laporan dibuat

**Cara Review Report:**
1. Expand card report
2. Klik "Review Report"
3. Baca detail laporan
4. Tambahkan admin notes (opsional)
5. Pilih action:
   - **Reject** - Laporan tidak valid
   - **Resolve** - Laporan valid dan sudah ditangani

#### Tab: All Reports
Melihat semua laporan (pending, reviewed, resolved, rejected) dengan status masing-masing.

## Fitur Report untuk User

### Cara User Melaporkan User Lain
```dart
// Di screen public profile atau booking detail
import 'package:rentlens/features/admin/presentation/widgets/report_dialog.dart';

// Tampilkan dialog
showReportDialog(
  context,
  reportType: ReportType.user,
  reportedUserId: userId,
  targetName: userName,
);
```

**Alasan Report User:**
- Spam or Scam
- Inappropriate Behavior
- Fraudulent Activity
- Harassment
- Fake Account
- Other (custom reason)

### Cara User Melaporkan Produk
```dart
// Di screen product detail
showReportDialog(
  context,
  reportType: ReportType.product,
  reportedProductId: productId,
  targetName: productName,
);
```

**Alasan Report Product:**
- Misleading Information
- Inappropriate Content
- Suspected Scam
- Counterfeit Product
- Overpriced
- Other (custom reason)

## Contoh Implementasi Report Button

### Product Detail Screen
Tambahkan tombol report di AppBar:

```dart
AppBar(
  title: const Text('Product Detail'),
  actions: [
    IconButton(
      icon: const Icon(Icons.report_outlined),
      tooltip: 'Report Product',
      onPressed: () {
        showReportDialog(
          context,
          reportType: ReportType.product,
          reportedProductId: product.id,
          targetName: product.name,
        );
      },
    ),
  ],
)
```

### Public Profile Screen
Tambahkan tombol report di profile:

```dart
IconButton(
  icon: const Icon(Icons.report_outlined),
  tooltip: 'Report User',
  onPressed: () {
    showReportDialog(
      context,
      reportType: ReportType.user,
      reportedUserId: userId,
      targetName: userName,
    );
  },
)
```

## Banned User Protection

### Proteksi Otomatis
User yang di-ban **TIDAK BISA**:
- Login ke aplikasi (akan otomatis logout)
- Membuat produk baru
- Membuat booking baru
- Mengakses fitur apapun

### Flow Banned User Login:
1. User banned coba login
2. Auth berhasil (Supabase Auth)
3. System cek `is_banned` di tabel users
4. Jika `is_banned = true`:
   - Otomatis sign out
   - Tampilkan dialog "Account Suspended"
   - User tidak bisa masuk aplikasi

### Database Policies (RLS)
```sql
-- Banned users cannot create products
CREATE POLICY "Banned users cannot create products"
    ON public.products
    FOR INSERT
    WITH CHECK (
        NOT EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND is_banned = TRUE
        )
    );

-- Banned users cannot create bookings
CREATE POLICY "Banned users cannot create bookings"
    ON public.bookings
    FOR INSERT
    WITH CHECK (
        NOT EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND is_banned = TRUE
        )
    );
```

## Testing Flow

### 1. Test Admin Login
```
1. Buat admin di database (SQL)
2. Buka aplikasi → Login
3. Masukkan email/password admin
4. Harus redirect ke /admin (Admin Dashboard)
5. Cek semua tab berfungsi
```

### 2. Test Ban User
```
1. Login sebagai admin
2. Pergi ke Users tab → All Users
3. Pilih user untuk di-ban
4. Klik icon block, masukkan reason
5. User di-ban
6. Coba login sebagai user tersebut
7. Harus muncul dialog "Account Suspended"
8. User tidak bisa masuk aplikasi
```

### 3. Test Report System
```
1. Login sebagai user biasa
2. Pergi ke product detail atau public profile
3. Klik tombol Report
4. Isi form laporan, submit
5. Login sebagai admin
6. Pergi ke Reports tab → Pending
7. Review laporan yang baru dibuat
8. Resolve atau Reject
9. Cek tab All Reports, status harus berubah
```

### 4. Test Unban User
```
1. Login sebagai admin
2. Pergi ke Users tab → Banned Users
3. Expand card user yang di-ban
4. Klik "Unban User"
5. Konfirmasi
6. Coba login sebagai user tersebut
7. User harus bisa login normal
```

## Security Notes

### ⚠️ PRODUCTION CHECKLIST:

1. **Password Hashing**
   ```dart
   // Update AdminRepository.authenticateAdmin()
   // Gunakan bcrypt untuk verify password hash
   import 'package:bcrypt/bcrypt.dart';
   
   final isValid = BCrypt.checkpw(password, storedPasswordHash);
   ```

2. **RLS Policies**
   - ✅ Sudah diimplementasi di migration SQL
   - Admin table hanya bisa diakses oleh admin
   - Reports bisa dibuat user, tapi hanya admin yang bisa review

3. **Input Validation**
   - ✅ Form validation di report dialog
   - ✅ Reason wajib diisi
   - ✅ Character limit 500 untuk description

4. **Rate Limiting**
   - Pertimbangkan rate limit untuk submit report
   - Cegah spam report dari satu user

## File Structure

```
lib/
├── core/
│   └── models/
│       ├── admin.dart           # Admin model
│       └── report.dart          # Report models & enums
├── features/
│   └── admin/
│       ├── data/
│       │   └── admin_repository.dart        # Repository untuk admin operations
│       ├── providers/
│       │   ├── admin_provider.dart          # AdminRepository provider
│       │   └── current_admin_provider.dart  # Current admin state
│       └── presentation/
│           ├── screens/
│           │   ├── admin_dashboard_screen.dart       # Main admin dashboard
│           │   ├── statistics_screen.dart            # Statistics tab
│           │   ├── users_management_screen.dart      # Users management
│           │   └── reports_management_screen.dart    # Reports management
│           └── widgets/
│               └── report_dialog.dart       # Report dialog untuk users
```

## Troubleshooting

### Admin tidak bisa login
- Cek apakah email ada di tabel `admins`
- Cek password match
- Lihat console log untuk error

### User masih bisa login setelah di-ban
- Cek kolom `is_banned` di tabel users
- Refresh page atau restart app
- Cek auth controller `checkBanStatus()`

### Report tidak muncul di admin
- Cek RLS policies untuk tabel reports
- Cek apakah admin_reports_view sudah dibuat
- Lihat console log untuk query errors

### Statistics tidak akurat
- Refresh page
- Cek apakah semua tabel memiliki data
- Invalidate provider: `ref.invalidate(adminStatisticsProvider)`

## API Reference

### AdminRepository Methods

```dart
// Authentication
Future<Admin?> authenticateAdmin(String email, String password)
Future<Admin?> getAdminByEmail(String email)

// User Management
Future<List<UserProfile>> getAllUsers({bool? isBanned, int? limit, int? offset})
Future<bool> banUser({required String userId, required String adminId, required String reason})
Future<bool> unbanUser(String userId)
Future<List<Map<String, dynamic>>> getBannedUsers()

// Reports Management
Future<List<ReportWithDetails>> getReports({ReportStatus? status, ReportType? type, int? limit})
Future<ReportWithDetails?> getReportById(String reportId)
Future<bool> updateReportStatus({required String reportId, required ReportStatus status, required String adminId, String? adminNotes})
Future<Report?> createReport({required String reporterId, required ReportType type, String? reportedUserId, String? reportedProductId, required String reason, String? description})

// Statistics
Future<Map<String, dynamic>> getStatistics()

// Product Management
Future<bool> deleteProduct(String productId)
Future<int> getUserReportsCount(String userId)
```

## Support
Untuk pertanyaan atau bug report terkait fitur admin, silakan buat issue di repository.
