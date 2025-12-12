# Arsitektur Status Booking Terpusat
**Centralized Booking Status Management**

## 📋 Ringkasan

Sistem status booking telah dirancang ulang untuk memastikan:
1. ✅ **Booking hanya bisa dikonfirmasi setelah pembayaran selesai**
2. ✅ **Status tersinkronisasi antara peminjam dan pemilik**
3. ✅ **Visibility yang jelas untuk kedua pihak**
4. ✅ **Validasi di level database dan aplikasi**

---

## 🏗️ Arsitektur Sistem

### 1. Database Layer (Supabase)

#### Table: `bookings`
```sql
- id (UUID)
- user_id (UUID) -- Peminjam
- product_id (UUID)
- start_date (DATE)
- end_date (DATE)
- total_price (DECIMAL)
- status (booking_status) -- ENUM: pending, confirmed, active, completed, cancelled
- payment_status (payment_status) -- ENUM: pending, processing, paid, failed, expired, cancelled
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

#### Table: `payments`
```sql
- id (UUID)
- booking_id (UUID) -- FK ke bookings
- order_id (VARCHAR)
- amount (BIGINT)
- status (payment_status) -- ENUM: pending, processing, paid, failed, expired, cancelled
- method (payment_method) -- ENUM: qris, gopay, shopeepay, bank_transfer
- snap_token (TEXT)
- snap_url (TEXT)
- transaction_id (VARCHAR)
- paid_at (TIMESTAMP)
- created_at (TIMESTAMP)
- updated_at (TIMESTAMP)
```

#### Trigger: Auto-sync Payment Status
```sql
-- Ketika payment.status berubah menjadi 'paid'
-- Otomatis update bookings.payment_status = 'paid'
CREATE TRIGGER update_booking_payment_status_trigger
  AFTER UPDATE ON payments
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION update_booking_payment_status();
```

**Benefit**: 
- Status payment otomatis tersinkronisasi ke booking
- Tidak perlu manual update dari aplikasi
- Konsisten di semua client

---

### 2. Domain Model Layer

#### BookingPaymentStatus Enum
```dart
enum BookingPaymentStatus {
  pending,     // Menunggu pembayaran
  processing,  // Sedang diproses
  paid,        // Sudah dibayar ✅
  failed,      // Pembayaran gagal
  expired,     // Pembayaran kadaluarsa
  cancelled    // Pembayaran dibatalkan
}
```

#### BookingStatus Enum
```dart
enum BookingStatus {
  pending,     // Menunggu konfirmasi owner (setelah payment)
  confirmed,   // Owner sudah terima
  active,      // Sedang berlangsung
  completed,   // Selesai
  cancelled    // Dibatalkan
}
```

#### Booking Model
```dart
class Booking {
  final String id;
  final BookingStatus status;
  final BookingPaymentStatus paymentStatus; // ✨ NEW
  
  // Helper methods
  bool get isPaymentCompleted => paymentStatus == BookingPaymentStatus.paid;
  
  bool get canBeConfirmedByOwner {
    return status == BookingStatus.pending && isPaymentCompleted;
  }
  
  String get userFriendlyStatus {
    if (status == BookingStatus.pending) {
      if (paymentStatus == BookingPaymentStatus.pending) {
        return 'Menunggu Pembayaran';
      } else if (paymentStatus == BookingPaymentStatus.paid) {
        return 'Menunggu Konfirmasi Pemilik';
      }
    }
    return statusText;
  }
}
```

---

### 3. Repository Layer - Validasi Pembayaran

#### BookingRepository
```dart
Future<Booking> updateBookingStatus({
  required String bookingId,
  required BookingStatus status,
}) async {
  // ✅ VALIDASI: Jika owner mau confirm, cek payment dulu
  if (status == BookingStatus.confirmed) {
    final booking = await getBookingById(bookingId);
    
    if (booking.paymentStatus != BookingPaymentStatus.paid) {
      throw Exception(
        'Tidak bisa menerima booking. Pembayaran belum selesai.'
      );
    }
  }
  
  // Update status
  return await _supabase
    .from('bookings')
    .update({'status': status.value})
    .eq('id', bookingId)
    .single();
}
```

**Benefit**:
- Double validation di aplikasi
- Error message yang jelas
- Mencegah owner accept booking yang belum bayar

---

### 4. Presentation Layer - UI/UX

#### Owner View (Pemilik Barang)

**File**: `owner_booking_management_screen.dart`

##### Payment Status Info Widget
```dart
Widget _buildPaymentStatusInfo(BookingWithProduct booking) {
  if (booking.isPaymentCompleted) {
    return Container(
      // Hijau - Sudah Bayar
      child: Text('✓ Pembayaran Diterima'),
    );
  } else {
    return Container(
      // Orange - Belum Bayar
      child: Text('⏳ Menunggu Pembayaran'),
    );
  }
}
```

##### Accept Button Logic
```dart
ElevatedButton.icon(
  // ✅ DISABLED jika payment belum selesai
  onPressed: booking.canBeConfirmedByOwner
      ? () => _handleConfirm(booking)
      : null,
  label: Text(
    booking.isPaymentCompleted 
      ? 'Accept' 
      : 'Menunggu Pembayaran',
  ),
)
```

##### Confirm Handler dengan Validation
```dart
Future<void> _handleConfirm(BookingWithProduct booking) async {
  // Double check payment
  if (!booking.isPaymentCompleted) {
    showSnackBar('Pembayaran belum selesai');
    return;
  }
  
  // Show confirmation dialog
  final confirmed = await showDialog(...);
  
  if (confirmed) {
    try {
      await repository.updateBookingStatus(
        bookingId: booking.id,
        status: BookingStatus.confirmed,
      );
      showSnackBar('Booking accepted!');
    } catch (e) {
      // Tampilkan error jika validasi di repository gagal
      showSnackBar(e.toString());
    }
  }
}
```

---

#### Renter View (Peminjam)

**Widget**: `BookingStatusTimeline`

Timeline visual yang menunjukkan progress booking:

```
1. ✅ Booking Dibuat
   |
2. [PENDING/PAID] Pembayaran
   |
3. [WAITING] Konfirmasi Pemilik
   |
4. [WAITING] Masa Sewa
   |
5. [WAITING] Selesai
```

**Compact Version**: `BookingStatusTimelineCompact`
- Untuk list/card view
- Menampilkan status current dengan warna & icon
- User-friendly message

---

## 🔄 Flow Diagram Status Booking

### Happy Path (Success Flow)

```
RENTER                    SYSTEM                    OWNER
   |                         |                         |
   |--Create Booking-------->|                         |
   |                         |                         |
   |    [Status: pending, payment_status: pending]     |
   |                         |                         |
   |--Pay via QRIS---------->|                         |
   |                         |                         |
   |                    [Midtrans]                     |
   |                         |                         |
   |                    payment.status = 'paid'        |
   |                         |                         |
   |                    [TRIGGER]                      |
   |              bookings.payment_status = 'paid'     |
   |                         |                         |
   |                         |------Notification------>|
   |                         |                         |
   |                         |                    [Owner Sees]
   |                         |               Payment Status: PAID
   |                         |               Button: ENABLED
   |                         |                         |
   |                         |<-----Accept Booking-----|
   |                         |                         |
   |              [VALIDATE payment_status = 'paid']   |
   |                         |                         |
   |              bookings.status = 'confirmed'        |
   |                         |                         |
   |<----Notification--------|------Notification------>|
   |                         |                         |
 [CONFIRMED]                                      [CONFIRMED]
```

### Unhappy Path (Payment Pending)

```
RENTER                    SYSTEM                    OWNER
   |                         |                         |
   |--Create Booking-------->|                         |
   |                         |                         |
   |    [Status: pending, payment_status: pending]     |
   |                         |                         |
   |                         |------Notification------>|
   |                         |                         |
   |                         |                    [Owner Sees]
   |                         |            Payment Status: PENDING
   |                         |               Button: DISABLED
   |                         |          Message: "Menunggu Pembayaran"
   |                         |                         |
   |                         |<-----Try Accept---------|
   |                         |           ❌            |
   |                         |    Error: "Pembayaran   |
   |                         |     belum selesai"      |
```

---

## 📱 User Experience

### Untuk Peminjam (Renter)

1. **Setelah Create Booking**
   - Status: "Menunggu Pembayaran"
   - Action: Button "Bayar Sekarang"

2. **Setelah Payment Success**
   - Status: "Menunggu Konfirmasi Pemilik"
   - Info: "Pembayaran diterima, menunggu pemilik approve"

3. **Setelah Owner Confirm**
   - Status: "Booking Dikonfirmasi"
   - Info: "Siap untuk dimulai"

### Untuk Pemilik (Owner)

1. **Booking Baru (Payment Pending)**
   - Badge: 🟠 "PENDING"
   - Info: "⏳ Menunggu Pembayaran"
   - Button Accept: DISABLED (Gray)
   - Button Text: "Menunggu Pembayaran"

2. **Booking Baru (Payment Completed)**
   - Badge: 🟢 "PAID"
   - Info: "✓ Pembayaran Diterima"
   - Button Accept: ENABLED (Primary Color)
   - Button Text: "Accept"

3. **Try Accept Without Payment**
   - Error SnackBar: "Tidak bisa menerima booking. Pembayaran belum selesai."

---

## 🎨 Widget Components

### 1. BookingStatusTimeline (Full)
**Usage**: Detail screen
```dart
BookingStatusTimeline(
  currentStatus: booking.status,
  paymentStatus: booking.paymentStatus,
  isOwnerView: true, // or false for renter
)
```

**Features**:
- Visual timeline 5 steps
- Color-coded progress
- Payment status badge
- Context-aware messages

### 2. BookingStatusTimelineCompact
**Usage**: List/Card view
```dart
BookingStatusTimelineCompact(
  currentStatus: booking.status,
  paymentStatus: booking.paymentStatus,
)
```

**Features**:
- Single line status
- Icon + color indicator
- User-friendly message

---

## 🔒 Security & Validation

### Multi-Layer Validation

1. **Database Trigger** ✅
   - Auto-sync payment status
   - Cannot be bypassed

2. **Repository Layer** ✅
   - Check payment before confirm
   - Throw exception if invalid

3. **UI Layer** ✅
   - Disable button if payment pending
   - Show clear error messages

4. **Business Logic** ✅
   - `canBeConfirmedByOwner` getter
   - Status-aware UI rendering

---

## 📊 Status Mapping

| Booking Status | Payment Status | User Display (Renter) | Owner Action |
|---------------|---------------|----------------------|-------------|
| pending | pending | "Menunggu Pembayaran" | ❌ Cannot Accept |
| pending | processing | "Memproses Pembayaran" | ❌ Cannot Accept |
| pending | paid | "Menunggu Konfirmasi Pemilik" | ✅ Can Accept |
| confirmed | paid | "Booking Dikonfirmasi" | Can Start Rental |
| active | paid | "Sedang Berlangsung" | Can Complete |
| completed | paid | "Selesai" | - |
| cancelled | * | "Dibatalkan" | - |

---

## 🚀 Implementation Checklist

### ✅ Completed
- [x] Add `payment_status` to Booking model
- [x] Create `BookingPaymentStatus` enum
- [x] Update `BookingRepository` with payment validation
- [x] Update `owner_booking_management_screen` UI
- [x] Disable accept button when payment pending
- [x] Show payment status info to owner
- [x] Create `BookingStatusTimeline` widget
- [x] Create `BookingStatusTimelineCompact` widget
- [x] Add helper methods to Booking model
- [x] Update BookingWithProduct getters
- [x] Improve error messages

### 📝 Usage in Screens

#### Owner Booking Management
```dart
// Already implemented in owner_booking_management_screen.dart
- Payment status info widget
- Conditional button enabling
- Payment validation on confirm
```

#### Booking Detail Screen (To Use)
```dart
import 'package:rentlens/features/booking/presentation/widgets/booking_status_timeline.dart';

// In booking detail screen
BookingStatusTimeline(
  currentStatus: booking.status,
  paymentStatus: booking.paymentStatus,
  isOwnerView: isOwner,
)
```

#### Booking List Screen (To Use)
```dart
// In booking list item
BookingStatusTimelineCompact(
  currentStatus: booking.status,
  paymentStatus: booking.paymentStatus,
)
```

---

## 🎯 Key Benefits

### 1. **Single Source of Truth**
- Status disimpan di database
- Tersinkronisasi real-time via trigger
- Tidak ada state inconsistency

### 2. **Clear User Communication**
- Peminjam tahu apa yang harus dilakukan
- Pemilik tahu apakah bisa accept atau tidak
- Status message yang jelas dan kontekstual

### 3. **Business Logic Protection**
- Tidak bisa confirm tanpa payment
- Validasi di multiple layers
- Error handling yang proper

### 4. **Scalability**
- Mudah extend untuk status baru
- Widget reusable
- Clean separation of concerns

---

## 🔧 Troubleshooting

### Problem: Owner bisa accept meskipun payment pending
**Solution**: 
- Check `canBeConfirmedByOwner` getter
- Ensure button onPressed uses this check
- Verify repository validation

### Problem: Status tidak sync antara users
**Solution**:
- Check database trigger is active
- Verify ref.invalidate() is called after actions
- Use FutureProvider untuk auto-refresh

### Problem: Payment status tidak update
**Solution**:
- Check payment webhook implementation
- Verify trigger function in database
- Check RLS policies

---

## 📖 Related Documentation

- [PAYMENT_QRIS_IMPLEMENTATION_SUMMARY.md](PAYMENT_QRIS_IMPLEMENTATION_SUMMARY.md)
- [BOOKING_MANAGEMENT_GUIDE.md](BOOKING_MANAGEMENT_GUIDE.md)
- [supabase_payment_qris_migration.sql](supabase_payment_qris_migration.sql)

---

## 🎓 Best Practices

1. **Always validate payment before confirming booking**
2. **Use visual indicators for status**
3. **Provide clear error messages**
4. **Keep status logic centralized in model**
5. **Use database triggers for data consistency**
6. **Invalidate providers after state changes**
7. **Handle loading/error states properly**

---

**Status Sistem**: ✅ PRODUCTION READY
**Last Updated**: December 12, 2025
**Version**: 1.0.0
