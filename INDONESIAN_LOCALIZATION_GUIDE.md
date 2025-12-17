# Panduan Standardisasi Bahasa UI ke Bahasa Indonesia

## Status Penyelesaian

### ✅ SELESAI
1. **lib/core/constants/app_strings.dart** - File pusat lokalisasi dibuat
2. **lib/features/auth/presentation/screens/login_screen.dart** - Semua teks diganti
3. **lib/features/auth/presentation/screens/register_screen.dart** - Semua teks diganti
4. **lib/features/home/presentation/screens/home_screen.dart** - Sebagian besar teks diganti
5. **lib/features/products/presentation/screens/add_product_page.dart** - Sebagian besar teks diganti
6. **lib/features/products/presentation/widgets/location_permission_banner.dart** - Teks utama diganti

### 🔄 PERLU DISELESAIKAN

#### Files dengan banyak teks bahasa Inggris:

**1. Booking Features** (PRIORITAS TINGGI)
- [ ] `lib/features/booking/presentation/screens/booking_form_screen.dart`
  - "New Booking", "Confirm Booking", "Rental Period", "Price Breakdown", "Delivery fee", dll
  
- [ ] `lib/features/booking/presentation/screens/booking_detail_screen.dart`
  - "Detail Pesanan", "Informasi Booking", "Terima Booking", "Tandai Selesai", "Bayar Sekarang", dll

- [ ] `lib/features/booking/presentation/screens/booking_history_screen.dart`
  - "Booking History", "Browse Products", "Start Date", "End Date", "Payment Proof", dll

- [ ] `lib/features/booking/presentation/screens/booking_list_screen.dart`
  - "Total Price", dll

- [ ] `lib/features/booking/presentation/widgets/booking_status_timeline.dart`
  - "Status Booking", "Booking Dibuat", "Konfirmasi Pemilik", "Masa Sewa", dll

**2. Product Features** (PRIORITAS TINGGI)
- [ ] `lib/features/products/presentation/screens/product_detail_screen.dart`
  - "Go Home", "Rental price", "per hari", "Product Owner", "Sewa Sekarang", "Edit Product", dll

- [ ] `lib/features/products/presentation/screens/product_list_screen.dart`
  - "All Products", "Retry", dll

- [ ] `lib/features/products/presentation/screens/my_listings_page.dart`
  - "Add Product", "Migration Required", dll

- [ ] `lib/features/products/presentation/widgets/location_status_header.dart`
  - "Your Location", dll

- [ ] `lib/features/products/presentation/widgets/no_nearby_products_widget.dart`
  - Berbagai teks yang perlu diganti

- [ ] `lib/features/products/presentation/widgets/zoomable_image_viewer.dart`

**3. Payment Features** (PRIORITAS TINGGI)
- [ ] `lib/features/payment/presentation/screens/payment_screen.dart`
  - "Product Rental", "View Booking", "Total Amount", "Order ID", "Payment Method", "Cancel Payment", "Payment Error", "Check Status", dll

- [ ] `lib/features/payment/domain/models/payment.dart`
  - "Paid", "Payment successful", "Failed", "Payment failed", "Cancelled", "Payment cancelled", "Bank Transfer", "Virtual Account", dll

**4. Profile/Auth Features** (PRIORITAS SEDANG)
- [ ] `lib/features/auth/presentation/screens/edit_profile_page.dart`
  - "Gagal memilih gambar", "Tidak dapat mengambil lokasi", "Lokasi diperbarui", "User not authenticated", "Profil berhasil diperbarui", dll

- [ ] `lib/features/auth/presentation/screens/public_profile_screen.dart`

- [ ] `lib/features/auth/presentation/screens/location_setup_page.dart`

**5. Admin Features** (PRIORITAS RENDAH)
- [ ] `lib/features/admin/presentation/screens/admin_dashboard_screen.dart`
- [ ] `lib/features/admin/presentation/screens/users_management_screen.dart`
- [ ] `lib/features/admin/presentation/screens/reports_management_screen.dart`
- [ ] `lib/features/admin/presentation/screens/statistics_screen.dart`
- [ ] `lib/features/admin/presentation/widgets/report_dialog.dart`
- [ ] `lib/features/admin/presentation/widgets/report_user_dialog.dart`

## Cara Menggunakan AppStrings

### Import Statement
Tambahkan di setiap file yang menggunakan teks UI:
```dart
import 'package:rentlens/core/constants/app_strings.dart';
```

### Contoh Penggunaan

#### Sebelum:
```dart
Text('Login')
```

#### Sesudah:
```dart
Text(AppStrings.login)
```

#### Sebelum:
```dart
labelText: 'Email'
```

#### Sesudah:
```dart
labelText: AppStrings.email
```

#### Sebelum (dengan variable):
```dart
'Produk berhasil ditambahkan!'
```

#### Sesudah:
```dart
AppStrings.productAdded
```

## Pola Teks yang Perlu Diganti

### 1. Button Text
- "Save" → `AppStrings.save`
- "Cancel" → `AppStrings.cancel`
- "Delete" → `AppStrings.delete`
- "Edit" → `AppStrings.edit`
- "Submit" → `AppStrings.submit`

### 2. Field Labels
- "Email" → `AppStrings.email`
- "Password" → `AppStrings.password`
- "Full Name" → `AppStrings.fullName`
- "Phone Number" → `AppStrings.phoneNumber`

### 3. Messages
- "Loading..." → `AppStrings.loading`
- "Error" → `AppStrings.error`
- "Success" → `AppStrings.success`

### 4. Validation Messages
- "Email wajib diisi" (sudah Indonesia) - gunakan `AppStrings.emailRequired`
- "Kata sandi minimal 6 karakter" (sudah Indonesia) - gunakan `AppStrings.passwordMinLength`

## Checklist Validasi

Setelah selesai mengganti semua teks, lakukan pemeriksaan:

- [ ] Jalankan aplikasi dan uji semua halaman
- [ ] Verifikasi tidak ada teks bahasa Inggris yang muncul di UI
- [ ] Test flow: Login → Daftar → Browse Products → Booking → Payment
- [ ] Test error messages dan validasi
- [ ] Test dialog dan snackbar
- [ ] Test menu dan navigasi
- [ ] Test empty states dan loading states

## Script untuk Menemukan Teks Bahasa Inggris yang Tersisa

Gunakan regex search di VS Code:
```regex
'[A-Z][a-z]+ [A-Z][a-z]+'|"[A-Z][a-z]+ [a-z]+"
```

Filter file path:
```
lib/features/**/*.dart
```

## Tips Implementasi

1. **Urutan Prioritas:**
   - Halaman yang sering diakses pengguna (Login, Home, Products)
   - Halaman booking dan payment (alur utama bisnis)
   - Halaman admin dan setting (jarang diakses)

2. **Testing:**
   - Test setiap halaman setelah mengganti teksnya
   - Pastikan tidak ada runtime error akibat typo di nama konstanta

3. **Konsistensi:**
   - Gunakan konstanta AppStrings, bukan hardcode Indonesian text
   - Ini memudahkan jika nanti ingin support multi-bahasa

4. **Pattern Matching:**
   - Cari semua `Text(`, `labelText:`, `hintText:`, `title:`, `content:`, dll
   - Periksa setiap string literal dan ganti dengan AppStrings

## Konstanta AppStrings yang Sudah Tersedia

Lihat file `lib/core/constants/app_strings.dart` untuk daftar lengkap.

**Kategori utama:**
- General (loading, save, cancel, dll)
- Authentication (login, register, password, dll)
- Profile (edit profile, avatar, dll)
- Location (GPS, permission, nearby, dll)
- Products (add, edit, delete, category, price, dll)
- Booking (booking, rental, status, timeline, dll)
- Payment (payment method, status, amount, dll)
- Admin (users, reports, statistics, dll)
- Errors & Messages
- Forms & Inputs
- Actions

## Contact untuk Bantuan

Jika menemukan teks yang tidak ada padanannya di AppStrings:
1. Tambahkan konstanta baru di `app_strings.dart`
2. Ikuti pola penamaan yang ada (camelCase, deskriptif)
3. Group berdasarkan kategori dengan comment section

## Progress Tracking

Gunakan todo list untuk melacak file yang sudah diselesaikan.
Update dokumen ini setelah menyelesaikan setiap file.
