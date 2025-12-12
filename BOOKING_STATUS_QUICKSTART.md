# 🎯 Quick Start: Status Booking System

## TL;DR

**Booking request (pending) hanya bisa diterima owner setelah pembayaran selesai.**

---

## ✅ Implementasi Lengkap

### 1. Model dengan Payment Status
```dart
class Booking {
  final BookingStatus status;
  final BookingPaymentStatus paymentStatus; // ✨ NEW
  
  bool get canBeConfirmedByOwner {
    return status == BookingStatus.pending && 
           paymentStatus == BookingPaymentStatus.paid;
  }
}
```

### 2. Repository dengan Validasi
```dart
Future<Booking> updateBookingStatus({
  required String bookingId,
  required BookingStatus status,
}) async {
  // ✅ Validasi: Owner tidak bisa confirm tanpa payment
  if (status == BookingStatus.confirmed) {
    final booking = await getBookingById(bookingId);
    if (booking.paymentStatus != BookingPaymentStatus.paid) {
      throw Exception('Pembayaran belum selesai');
    }
  }
  // ... update status
}
```

### 3. UI Owner - Conditional Accept Button
```dart
ElevatedButton.icon(
  // ✅ DISABLED jika payment belum selesai
  onPressed: booking.canBeConfirmedByOwner 
    ? () => _handleConfirm(booking) 
    : null,
  label: Text(
    booking.isPaymentCompleted 
      ? 'Accept' 
      : 'Menunggu Pembayaran'
  ),
)
```

### 4. Payment Status Info Widget
```dart
// ✅ Menampilkan status pembayaran ke owner
if (booking.status == BookingStatus.pending) {
  _buildPaymentStatusInfo(booking),
}
```

---

## 🔄 Status Flow

```
1. PEMINJAM membuat booking
   └─> status: pending, payment_status: pending

2. PEMINJAM bayar via QRIS
   └─> payment_status: paid (auto via trigger database)

3. OWNER melihat payment status: PAID ✅
   └─> Button "Accept" ENABLED

4. OWNER klik Accept
   └─> Validasi payment di repository ✅
   └─> status: confirmed

5. BOOKING DIKONFIRMASI ✅
```

---

## 🎨 Widget Timeline Status

### Full Timeline (Detail Screen)
```dart
BookingStatusTimeline(
  currentStatus: booking.status,
  paymentStatus: booking.paymentStatus,
  isOwnerView: true,
)
```

### Compact Timeline (List View)
```dart
BookingStatusTimelineCompact(
  currentStatus: booking.status,
  paymentStatus: booking.paymentStatus,
)
```

---

## 📊 Status Mapping

| Status Booking | Payment Status | Tampilan User | Owner Action |
|---------------|---------------|---------------|-------------|
| pending | pending | "Menunggu Pembayaran" | ❌ Tidak bisa Accept |
| pending | paid | "Menunggu Konfirmasi" | ✅ Bisa Accept |
| confirmed | paid | "Dikonfirmasi" | Bisa Start Rental |
| active | paid | "Sedang Berlangsung" | Bisa Complete |
| completed | paid | "Selesai" | - |

---

## 🔐 Multi-Layer Protection

1. **Database Trigger** - Auto sync payment status
2. **Repository Validation** - Cek payment sebelum confirm
3. **UI Validation** - Disable button jika payment pending
4. **Business Logic** - Helper methods di model

---

## 📝 Files Modified

1. [booking.dart](lib/features/booking/domain/models/booking.dart)
   - ✅ Added `BookingPaymentStatus` enum
   - ✅ Added `paymentStatus` field
   - ✅ Added helper methods

2. [booking_with_product.dart](lib/features/booking/domain/models/booking_with_product.dart)
   - ✅ Added payment status getters

3. [booking_repository.dart](lib/features/booking/data/repositories/booking_repository.dart)
   - ✅ Added payment validation in `updateBookingStatus()`

4. [owner_booking_management_screen.dart](lib/features/booking/presentation/screens/owner_booking_management_screen.dart)
   - ✅ Added payment status info widget
   - ✅ Conditional button enabling
   - ✅ Enhanced error handling

5. [booking_status_timeline.dart](lib/features/booking/presentation/widgets/booking_status_timeline.dart) ✨ NEW
   - ✅ Full timeline widget
   - ✅ Compact timeline widget

---

## 🚀 Usage Examples

### Example 1: Booking Detail Screen
```dart
// Show full timeline
Column(
  children: [
    BookingStatusTimeline(
      currentStatus: booking.status,
      paymentStatus: booking.paymentStatus,
      isOwnerView: isOwner,
    ),
  ],
)
```

### Example 2: Booking List Card
```dart
// Show compact status
Card(
  child: Column(
    children: [
      // ... product info ...
      BookingStatusTimelineCompact(
        currentStatus: booking.status,
        paymentStatus: booking.paymentStatus,
      ),
    ],
  ),
)
```

### Example 3: Check Before Action
```dart
// Before performing action
if (booking.canBeConfirmedByOwner) {
  // Safe to confirm
  await confirmBooking();
} else {
  // Show error
  showError('Payment belum selesai');
}
```

---

## ❓ FAQ

**Q: Bagaimana cara owner tahu payment sudah selesai?**
A: Owner akan melihat badge "✓ Pembayaran Diterima" berwarna hijau, dan button Accept akan enabled.

**Q: Apa yang terjadi jika owner coba accept sebelum payment?**
A: Button akan disabled (gray) dengan text "Menunggu Pembayaran". Jika somehow di-trigger, repository akan throw error.

**Q: Apakah peminjam bisa lihat status yang sama?**
A: Ya, gunakan widget `BookingStatusTimeline` dengan `isOwnerView: false` untuk perspektif peminjam.

**Q: Bagaimana sync status antara users?**
A: Database trigger otomatis update `payment_status` di table `bookings` ketika payment berhasil. Riverpod provider akan refresh UI.

---

## 📚 Dokumentasi Lengkap

Lihat: [BOOKING_STATUS_ARCHITECTURE.md](BOOKING_STATUS_ARCHITECTURE.md)

---

**Version**: 1.0.0  
**Status**: ✅ Production Ready  
**Last Updated**: December 12, 2025
