# Quick Reference: Indonesian UI Strings

## 🎯 Quick Access

All UI strings are centralized in:
```
lib/core/constants/app_strings.dart
```

## 📖 How to Use

### Import the Constants
```dart
import 'package:rentlens/core/constants/app_strings.dart';
```

### Use in Widgets
```dart
// Good ✅
Text(AppStrings.productNotFound)

// Bad ❌
Text('Product not found')
```

---

## 🗂️ String Categories

### General Actions
```dart
AppStrings.ok           // OK
AppStrings.cancel       // Batal
AppStrings.save         // Simpan
AppStrings.delete       // Hapus
AppStrings.edit         // Edit
AppStrings.retry        // Coba Lagi
AppStrings.refresh      // Perbarui
AppStrings.yes          // Ya
AppStrings.no           // Tidak
AppStrings.confirm      // Konfirmasi
```

### Authentication
```dart
AppStrings.login        // Masuk
AppStrings.register     // Daftar
AppStrings.logout       // Keluar
AppStrings.email        // Email
AppStrings.password     // Kata Sandi
AppStrings.fullName     // Nama Lengkap
```

### Products
```dart
AppStrings.products                // Produk
AppStrings.myProducts              // Produk Saya
AppStrings.addProduct              // Tambah Produk
AppStrings.editProduct             // Edit Produk
AppStrings.deleteProduct           // Hapus Produk
AppStrings.productDetails          // Detail Produk
AppStrings.productNotFound         // Produk tidak ditemukan
AppStrings.availableForRent        // Tersedia untuk disewa
AppStrings.notAvailable            // Tidak Tersedia
AppStrings.rentalPrice             // Harga Sewa
AppStrings.owner                   // Pemilik
```

### Booking
```dart
AppStrings.booking                    // Booking
AppStrings.myBookings                 // Pesanan Saya
AppStrings.bookingHistory             // Riwayat Booking
AppStrings.createBooking              // Buat Booking
AppStrings.confirmBookingTitle        // Konfirmasi Booking
AppStrings.bookingSubmittedSuccessfully // Booking berhasil dikirim!
AppStrings.acceptBooking              // Terima Booking
AppStrings.rejectBooking              // Tolak Booking
AppStrings.cancelBooking              // Batalkan Booking
AppStrings.startDate                  // Tanggal Mulai
AppStrings.endDate                    // Tanggal Selesai
AppStrings.totalPrice                 // Total Harga
```

### Payment
```dart
AppStrings.payment                 // Pembayaran
AppStrings.payNow                  // Bayar Sekarang
AppStrings.paymentMethod           // Metode Pembayaran
AppStrings.paymentSuccessful       // Pembayaran Berhasil!
AppStrings.paymentPending          // Menunggu Pembayaran
AppStrings.paymentFailed           // Pembayaran Gagal
AppStrings.totalAmount             // Total Jumlah
AppStrings.qris                    // QRIS
```

### Location
```dart
AppStrings.locationPermission             // Izin Lokasi
AppStrings.locationRequired               // Lokasi Diperlukan
AppStrings.enableLocation                 // Aktifkan Lokasi
AppStrings.nearbyProducts                 // Produk Terdekat
AppStrings.loadingNearbyProducts          // Memuat produk terdekat...
AppStrings.noNearbyProducts               // Tidak Ada Produk Terdekat
AppStrings.locationPermissionRequired     // Izin lokasi diperlukan
AppStrings.gettingYourLocation            // Mendapatkan lokasi Anda...
```

### Status Messages
```dart
AppStrings.loading               // Memuat...
AppStrings.error                 // Kesalahan
AppStrings.success               // Berhasil
AppStrings.failed                // Gagal
AppStrings.completed             // Selesai
AppStrings.processing            // Memproses...
AppStrings.saving                // Menyimpan...
AppStrings.uploading             // Mengunggah...
```

### Empty States
```dart
AppStrings.noData                  // Tidak ada data
AppStrings.noProducts              // Belum Ada Produk
AppStrings.noBookings              // Belum Ada Booking
AppStrings.noListingsYet           // Belum ada listing
AppStrings.noResults               // Tidak ada hasil
```

### Profile
```dart
AppStrings.profile                    // Profil
AppStrings.editProfile                // Edit Profil
AppStrings.myProfile                  // Profil Saya
AppStrings.updateProfile              // Perbarui Profil
AppStrings.profileUpdatedSuccessfully // Profil berhasil diperbarui!
AppStrings.bio                        // Bio
AppStrings.address                    // Alamat
AppStrings.city                       // Kota
AppStrings.phoneNumber                // Nomor Telepon
```

### Admin
```dart
AppStrings.adminDashboard          // Dashboard Admin
AppStrings.userManagement          // Kelola Pengguna
AppStrings.reportManagement        // Kelola Laporan
AppStrings.banUser                 // Blokir Pengguna
AppStrings.unbanUser               // Buka Blokir Pengguna
AppStrings.reportUser              // Laporkan Pengguna
AppStrings.statistics              // Statistik
```

---

## 🎨 Common Patterns

### Error Handling
```dart
try {
  // ... operation
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('${AppStrings.error}: $e')),
  );
}
```

### Confirmation Dialogs
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(AppStrings.confirmAction),
    content: Text(AppStrings.confirmBookingMessage),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(AppStrings.cancel),
      ),
      ElevatedButton(
        onPressed: () {
          // Proceed
          Navigator.pop(context);
        },
        child: Text(AppStrings.confirm),
      ),
    ],
  ),
);
```

### Loading States
```dart
if (isLoading) {
  return Center(child: Text(AppStrings.loading));
}
```

### Empty States
```dart
if (items.isEmpty) {
  return Center(child: Text(AppStrings.noData));
}
```

---

## 🔍 Search Tips

### Find String by English Keyword
Search `app_strings.dart` for:
- `login` → finds `static const String login`
- `book` → finds all booking-related strings
- `payment` → finds all payment strings

### Naming Convention
All strings follow: `categoryDescription` pattern
- `booking` + `Submitted` + `Successfully` = `bookingSubmittedSuccessfully`
- `location` + `Permission` + `Required` = `locationPermissionRequired`
- `payment` + `Successful` = `paymentSuccessful`

---

## ✅ Best Practices

### DO ✅
```dart
// Use constants
Text(AppStrings.productName)

// Combine with variables
Text('${AppStrings.error}: $errorMessage')

// Use in widgets
hintText: AppStrings.emailHint
```

### DON'T ❌
```dart
// Hardcode strings
Text('Product Name')

// Mix languages
Text('Product: $name')

// Duplicate strings
const String myProductString = 'Produk';  // Use AppStrings.products instead
```

---

## 📱 Testing Checklist

✅ **Login/Register** - All fields, buttons, errors  
✅ **Home Screen** - Categories, search, no results  
✅ **Product List** - Empty state, loading, errors  
✅ **Product Detail** - All labels, buttons, owner info  
✅ **Booking Form** - All fields, validation, confirmation  
✅ **Payment Screen** - Status, methods, instructions  
✅ **Profile** - View, edit, location  
✅ **Admin** - User management, reports  
✅ **Dialogs** - Confirmations, errors, success messages  
✅ **Navigation** - Menu items, tooltips  

---

## 📞 Support

**Problem:** Can't find a string for my UI text  
**Solution:** Add it to `app_strings.dart` following the naming convention

**Problem:** String doesn't sound natural in Indonesian  
**Solution:** Update the value in `app_strings.dart` - all usages will automatically update

**Problem:** Need to add new feature with UI text  
**Solution:** 
1. Add strings to `app_strings.dart`
2. Use `AppStrings.yourNewString` in widgets
3. Never hardcode text

---

**Last Updated:** December 17, 2025  
**Status:** ✅ Complete
