# 🚀 QUICK START: Lanjutkan Standardisasi UI ke Bahasa Indonesia

## ✅ APA YANG SUDAH SELESAI

1. **Core Infrastructure** ✓
   - File `lib/core/constants/app_strings.dart` dengan 400+ konstanta
   - Semua kategori teks sudah didefinisikan

2. **Authentication Screens** ✓
   - Login Screen: 100% Indonesian
   - Register Screen: 100% Indonesian
   - Validation messages, error dialogs: 100% Indonesian

3. **Partial Updates** ✓
   - Home Screen: Menu, search bar, categories
   - Add Product Page: Forms, validations, messages
   - Location Permission Banner: Button labels

## 🎯 PRIORITAS KERJA BERIKUTNYA

### TOP 5 FILES TO UPDATE NOW (Estimasi: 2-3 jam)

Kelima file ini adalah yang paling sering dilihat user:

1. **booking_detail_screen.dart** (30 menit)
   - File: `lib/features/booking/presentation/screens/booking_detail_screen.dart`
   - Import sudah ada: ✅
   - Strings to replace: "Terima Booking", "Tandai Selesai", "Bayar Sekarang", dll
   
2. **booking_form_screen.dart** (30 menit)
   - File: `lib/features/booking/presentation/screens/booking_form_screen.dart`
   - Import sudah ada: ✅
   - Strings to replace: "New Booking", "Confirm Booking", "Price Breakdown", dll

3. **product_detail_screen.dart** (25 menit)
   - File: `lib/features/products/presentation/screens/product_detail_screen.dart`
   - Import sudah ada: ✅
   - Strings to replace: "Go Home", "Rental price", "Sewa Sekarang", dll

4. **payment_screen.dart** (25 menit)
   - File: `lib/features/payment/presentation/screens/payment_screen.dart`
   - Import sudah ada: ✅
   - Strings to replace: "Order ID", "Payment Method", "Cancel Payment", dll

5. **booking_history_screen.dart** (20 menit)
   - File: `lib/features/booking/presentation/screens/booking_history_screen.dart`
   - Import sudah ada: ✅
   - Strings to replace: "Booking History", "Browse Products", dll

## 📖 CARA KERJA (Step-by-step)

### Step 1: Buka File
Pilih salah satu file dari daftar prioritas di atas.

### Step 2: Find English Strings
Gunakan Ctrl+F (Find) dan cari pattern:
- `Text('`
- `Text("`
- `labelText: '`
- `hintText: '`
- `title: '`
- `content: '`

### Step 3: Cek AppStrings
Buka `lib/core/constants/app_strings.dart` dan cari konstanta yang sesuai.

**Contoh:**
- `'Booking History'` → `AppStrings.bookingHistory`
- `'Cancel Payment'` → `AppStrings.cancelPayment`
- `'Order ID'` → `AppStrings.orderId`

### Step 4: Replace
Ganti hardcoded string dengan konstanta AppStrings.

**Sebelum:**
```dart
Text('Booking History')
```

**Sesudah:**
```dart
Text(AppStrings.bookingHistory)
```

### Step 5: Jika Konstanta Belum Ada

Tambahkan di `app_strings.dart`:

```dart
// Di section yang sesuai (misal: BOOKING)
static const String newConstant = 'Teks Indonesia';
```

### Step 6: Save & Test
- Save file
- Jalankan app (optional): `flutter run`
- Cek tidak ada compile error

## 🔍 CHEAT SHEET: Common Replacements

### Booking Strings
```dart
'New Booking' → AppStrings.newBooking
'Booking Details' → AppStrings.bookingDetails
'Confirm Booking' → AppStrings.bookingCreated
'Cancel Booking' → AppStrings.cancelBooking
'Accept Booking' → AppStrings.acceptBooking
'Reject Booking' → AppStrings.rejectBooking
'Start Date' → AppStrings.startDate
'End Date' → AppStrings.endDate
'Rental Period' → AppStrings.rentalPeriod
'Total Price' → AppStrings.totalPrice
```

### Payment Strings
```dart
'Payment Method' → AppStrings.paymentMethod
'Order ID' → AppStrings.orderId
'Pay Now' → AppStrings.payNow
'Payment Status' → AppStrings.paymentStatus
'Total Amount' → AppStrings.paymentAmount
'Cancel Payment' → AppStrings.cancelPayment
```

### Product Strings
```dart
'Product Details' → AppStrings.productDetails
'Rental price' → AppStrings.rentalPrice
'per hari' → AppStrings.perDay
'Edit Product' → AppStrings.editProduct
'Delete Product' → AppStrings.deleteProduct
'Sewa Sekarang' → AppStrings.rentNow  
'Tidak Tersedia' → AppStrings.notAvailableShort
```

### Common UI
```dart
'Go Home' → AppStrings.goHome
'Retry' → AppStrings.retry
'Save' → AppStrings.save
'Cancel' → AppStrings.cancel
'Delete' → AppStrings.delete
'Loading...' → AppStrings.loading
```

## ⚡ FASTEST WAY: Multi-Replace

Jika familiar dengan regex, gunakan Find & Replace (Ctrl+H) di VS Code:

**Find:**
```regex
Text\('([^']+)'\)
```

**Replace (manual - cek satu-satu):**
```
Text(AppStrings.xxx)
```

⚠️ **Warning:** Jangan auto-replace semua! Check satu-satu untuk memastikan.

## 🐛 TROUBLESHOOTING

### Error: "AppStrings not found"
**Solusi:** Pastikan import sudah ada di top file:
```dart
import 'package:rentlens/core/constants/app_strings.dart';
```

### Error: "xxx is not defined"
**Solusi:** Konstanta belum ada di AppStrings. Tambahkan dulu.

### Masih ada English text
**Solusi:** Cari dengan regex pattern:
```
'[A-Z][a-z]+ [A-Z][a-z]+'
```

## 📊 TRACK PROGRESS

Update checklist di `INDONESIAN_LOCALIZATION_SUMMARY.md` setelah selesai.

## ✅ DEFINITION OF DONE

Sebuah file dianggap selesai jika:
- [ ] Semua UI text menggunakan AppStrings (bukan hardcoded)
- [ ] Tidak ada English text yang muncul saat runtime
- [ ] File compile tanpa error
- [ ] Checklist di SUMMARY.md diupdate

## 🎯 TARGET

**Total work remaining:** ~3-4 jam
**Files to complete:** 15-20 files
**Priority:** User-facing screens dulu

## 💡 PRO TIPS

1. **Kerjakan per category**: Selesaikan semua booking files dulu, baru payment, dll
2. **Test incremental**: Test app setelah 2-3 files untuk catch errors early
3. **Use VSCode's "Go to Definition"**: Ctrl+Click pada AppStrings untuk cek nilai aslinya
4. **Bookmark app_strings.dart**: Sering dibuka untuk referensi
5. **Use split editor**: Buka app_strings.dart di satu side, file yang diupdate di side lain

---

**Ready to start?** Buka file pertama dan mulai replace! 🚀
