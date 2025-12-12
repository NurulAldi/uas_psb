# QRIS Payment Testing Guide

## Overview
Panduan lengkap untuk testing implementasi QRIS payment dengan Midtrans Sandbox.

## Prerequisites
1. ✅ Database migration sudah dijalankan (`supabase_payment_qris_migration.sql`)
2. ✅ Environment variables sudah dikonfigurasi di `.env`
3. ✅ Dependencies sudah diinstall (`flutter pub get`)

## Setup Database

### 1. Run Migration SQL
Buka Supabase Dashboard → SQL Editor → Paste isi file:
```
supabase_payment_qris_migration.sql
```

Klik "RUN" untuk execute migration.

### 2. Verifikasi Tables
Check tables yang harus ada:
- `payments` - Table untuk menyimpan data payment
- `bookings` - Harus ada column `payment_status`

Query test:
```sql
SELECT * FROM payments LIMIT 5;
SELECT id, status, payment_status FROM bookings LIMIT 5;
```

## Testing Payment Flow

### Scenario 1: Complete QRIS Payment (Happy Path)

#### Step 1: Create Booking
1. Login ke aplikasi
2. Browse products → Pilih product
3. Klik "Book Now"
4. Isi form booking:
   - Start date
   - End date
   - Delivery method (Pickup/Delivery)
   - Notes (optional)
5. Klik "Submit Booking"

#### Step 2: Navigate to Payment
1. Setelah booking created, akan redirect ke Booking Detail
2. Status booking harus **"Pending"**
3. Klik tombol **"Pay Now"** (biru, dengan ikon payment)
4. Akan redirect ke Payment Screen

#### Step 3: View QRIS Page
Payment Screen akan menampilkan:
- Total amount di header (formatted: Rp 100.000)
- Status badge (PENDING - orange)
- Payment method (QRIS icon)
- WebView dengan halaman Midtrans Snap
- 2 tombol di bottom: "Open in Browser" dan "Check Status"

#### Step 4: Simulate Payment (Sandbox)

**Option A: Scan QR Code (Recommended)**
1. QR code akan muncul di WebView
2. Gunakan test QR code dari Midtrans Sandbox
3. Status akan otomatis update setelah payment success

**Option B: Click "Bayar" Button**
Di halaman Midtrans Snap (sandbox), klik tombol "Bayar":
1. Akan muncul form simulasi
2. Pilih salah satu:
   - **Success** - Payment berhasil
   - **Pending** - Payment pending
   - **Failure** - Payment gagal
3. Klik "Submit"

#### Step 5: Check Status
1. Setelah payment, klik "Check Status" button
2. Atau tunggu 5 detik (auto-refresh)
3. Jika success, akan muncul dialog:
   - ✅ Icon hijau
   - "Payment Successful!"
   - Button "View Booking"
4. Klik "View Booking" → redirect ke Booking Detail

#### Step 6: Verify Booking Update
Di Booking Detail:
- Status booking harus berubah ke **"Confirmed"** (dari trigger)
- Payment status di badge (jika ditampilkan)

### Scenario 2: Payment Failed

#### Test Failed Transaction
1. Follow Step 1-3 dari Scenario 1
2. Di halaman Midtrans Snap, pilih **"Failure"**
3. Status check akan trigger failed dialog:
   - ❌ Icon merah
   - "Payment Failed"
   - 2 buttons: "Cancel" dan "Retry Payment"
4. Test actions:
   - **Cancel** → Back ke booking list
   - **Retry Payment** → Create new payment transaction

### Scenario 3: Payment Expired

#### Test Expired Transaction
Payment akan auto-expire setelah 24 jam (Midtrans default).

Manual test:
1. Create payment
2. Jangan bayar
3. Tunggu atau set manual di database:
```sql
UPDATE payments 
SET status = 'expired' 
WHERE order_id = 'RENT-xxx';
```
4. Check status → Akan show "Payment Expired"

### Scenario 4: Open in Browser

#### Test External Browser
1. Di Payment Screen, klik "Open in Browser"
2. Akan buka browser default (Chrome/Safari)
3. Halaman Midtrans Snap akan load
4. Complete payment di browser
5. Kembali ke app
6. Klik "Check Status" untuk update

## Database Verification

### Check Payment Records
```sql
SELECT 
  p.id,
  p.order_id,
  p.amount,
  p.status,
  p.method,
  p.transaction_id,
  p.created_at,
  p.paid_at,
  b.status AS booking_status,
  b.payment_status AS booking_payment_status
FROM payments p
JOIN bookings b ON b.id = p.booking_id
ORDER BY p.created_at DESC
LIMIT 10;
```

### Check Trigger Execution
Verify booking status auto-update:
```sql
-- Before payment
SELECT id, status, payment_status FROM bookings WHERE id = 'xxx';
-- Expected: status = 'pending', payment_status = 'pending'

-- After payment
SELECT id, status, payment_status FROM bookings WHERE id = 'xxx';
-- Expected: status = 'confirmed', payment_status = 'paid'
```

### Check RLS Policies
Test sebagai user:
```sql
-- Should only see own payments
SELECT * FROM payments;

-- Should only see own bookings
SELECT * FROM bookings;
```

## Midtrans Sandbox Testing

### Test Credentials


### Sandbox URLs
- **Snap Page**: https://app.sandbox.midtrans.com/snap/v1/transactions/{token}
- **API**: https://api.sandbox.midtrans.com/v2
- **Dashboard**: https://dashboard.sandbox.midtrans.com

### Test Card Numbers (if using Credit Card)
- **Success**: 4811 1111 1111 1114
- **Failure**: 4911 1111 1111 1113
- CVV: 123
- Expire: Any future date

### Test Phone Numbers (GoPay/ShopeePay)
- Any phone number: 081234567890
- Will show simulator in sandbox

## API Testing

### 1. Create Transaction
```dart
final midtrans = MidtransService();
final result = await midtrans.createTransaction(
  orderId: 'TEST-ORDER-123',
  grossAmount: 100000,
  customerName: 'Test User',
  customerEmail: 'test@example.com',
  customerPhone: '081234567890',
);

print(result);
// Expected: {success: true, token: xxx, redirect_url: xxx}
```

### 2. Check Status
```dart
final status = await midtrans.checkTransactionStatus('TEST-ORDER-123');
print(status);
// Expected: {success: true, transaction_status: 'pending', ...}
```

### 3. Cancel Transaction
```dart
final cancel = await midtrans.cancelTransaction('TEST-ORDER-123');
print(cancel);
// Expected: {success: true, message: 'Transaction cancelled'}
```

## Common Issues & Solutions

### Issue 1: Payment Screen Blank (White Screen)
**Cause**: Snap URL invalid or expired
**Solution**:
1. Check logs: `print(_payment?.snapUrl)`
2. Verify token creation: Check Midtrans API response
3. Retry payment: Delete old payment, create new

### Issue 2: Status Not Updating
**Cause**: Polling not working or API error
**Solution**:
1. Check logs for API errors
2. Verify Server Key in `.env`
3. Manually check status: Click "Check Status" button
4. Check internet connection

### Issue 3: Database Trigger Not Working
**Cause**: Trigger not created or RLS blocking
**Solution**:
1. Re-run migration SQL
2. Check trigger exists:
```sql
SELECT * FROM pg_trigger WHERE tgname = 'on_payment_status_change';
```
3. Test trigger manually:
```sql
UPDATE payments SET status = 'paid' WHERE id = 'xxx';
-- Then check bookings table
```

### Issue 4: RLS Policy Error
**Cause**: User doesn't have permission
**Solution**:
1. Check authenticated user:
```dart
final user = Supabase.instance.client.auth.currentUser;
print(user?.id);
```
2. Verify booking belongs to user:
```sql
SELECT user_id FROM bookings WHERE id = 'xxx';
```
3. Check RLS policies in Supabase Dashboard

### Issue 5: WebView Not Loading
**Cause**: WebView not initialized or URL invalid
**Solution**:
1. Check WebViewController initialization
2. Verify URL format: Should start with `https://`
3. Check WebView permissions in AndroidManifest.xml
4. Try "Open in Browser" button as fallback

## Manual Testing Checklist

### Pre-Test
- [ ] Database migration executed
- [ ] .env file configured
- [ ] Dependencies installed
- [ ] App compiled without errors

### Happy Path
- [ ] Create booking successfully
- [ ] Navigate to payment screen
- [ ] View QRIS page in WebView
- [ ] Simulate payment (success)
- [ ] Status dialog appears
- [ ] Booking status updated
- [ ] Payment record saved in DB

### Error Handling
- [ ] Test payment failed scenario
- [ ] Test payment expired scenario
- [ ] Test network error (offline)
- [ ] Test invalid booking ID
- [ ] Test cancel booking action

### UI/UX
- [ ] Payment amount formatted correctly
- [ ] Status badge shows correct color
- [ ] Loading states visible
- [ ] Error messages user-friendly
- [ ] Buttons responsive and clear
- [ ] Navigation smooth (back button works)

### Security
- [ ] Can only pay for own bookings
- [ ] Can only view own payments
- [ ] Server Key not exposed in UI
- [ ] API calls authenticated

## Expected Behavior Summary

### Payment Status Flow
```
pending → processing → paid
        ↘ failed
        ↘ expired
        ↘ cancelled
```

### Booking Status Flow (Auto-Updated)
```
Payment pending → Booking pending
Payment paid → Booking confirmed (via trigger)
Payment failed → Booking pending (manual retry)
Payment cancelled → Booking cancelled
```

### UI States
1. **Loading**: CircularProgressIndicator + "Loading payment..."
2. **Pending**: WebView with QRIS + "Pay Now" button
3. **Processing**: Status checking + "Checking payment..."
4. **Success**: Green dialog + "Payment Successful!"
5. **Failed**: Red dialog + "Payment Failed" + Retry button
6. **Error**: Red icon + Error message + Retry button

## Next Steps After Testing

### If All Tests Pass ✅
1. Mark task as completed in todo list
2. Document any bugs found
3. Ready for production (change `MIDTRANS_IS_PRODUCTION=true`)
4. Update Server/Client keys with production keys

### If Tests Fail ❌
1. Check logs for errors
2. Verify database schema
3. Check API responses
4. Review code for bugs
5. Ask for help if stuck

## Production Deployment

### Before Going Live
1. Get Midtrans Production Account
   - Apply at: https://midtrans.com
   - Submit business documents
   - Wait for approval (2-5 days)
2. Update credentials in `.env`:
```
MIDTRANS_SERVER_KEY=your_production_server_key
MIDTRANS_CLIENT_KEY=your_production_client_key
MIDTRANS_IS_PRODUCTION=true
```
3. Test thoroughly in production sandbox first
4. Deploy to production

### Production URLs
- **Snap Page**: https://app.midtrans.com/snap/v1/transactions/{token}
- **API**: https://api.midtrans.com/v2
- **Dashboard**: https://dashboard.midtrans.com

## Support & Resources

### Midtrans Documentation
- API Docs: https://docs.midtrans.com
- Snap Guide: https://docs.midtrans.com/en/snap/overview
- QRIS Guide: https://docs.midtrans.com/en/core-api/qris

### Troubleshooting
- Midtrans FAQ: https://docs.midtrans.com/en/faqs
- Status Codes: https://docs.midtrans.com/en/after-payment/status-cycle
- Error Codes: https://docs.midtrans.com/en/technical-reference/error-response-code

### Contact
- Midtrans Support: support@midtrans.com
- Midtrans Slack: midtrans-users.slack.com
