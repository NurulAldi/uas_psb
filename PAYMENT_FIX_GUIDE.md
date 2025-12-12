# 🔧 FIX: Payment Tidak Tersimpan di Database

## 🎯 Masalah
Ketika user mendownload QR code untuk pembayaran, status payment berubah di UI tapi **tidak tersimpan di database**. Akibatnya owner tidak bisa lihat status "Paid" di Booking Requests.

---

## 🔍 Root Cause Analysis

### 1. **RLS (Row Level Security) Policy Tidak Lengkap**
Policy UPDATE di tabel `payments` terlalu umum dan tidak spesifik:
```sql
-- POLICY LAMA (TERLALU PERMISIF)
CREATE POLICY "System can update payments"
  ON payments FOR UPDATE
  USING (true)  -- ❌ Terlalu luas, bisa konflik
  WITH CHECK (true);
```

### 2. **Owner Tidak Bisa Lihat Payment**
Tidak ada policy yang mengizinkan **owner produk** untuk melihat payment dari booking produknya.

---

## ✅ Solusi

### File 1: `supabase_fix_payment_rls.sql`
SQL untuk memperbaiki RLS policies di Supabase.

**Jalankan SQL ini di Supabase SQL Editor:**

#### Policy Baru:

1. **Users can view own payments** - User peminjam bisa lihat payment mereka
2. **Owners can view payments for their products** - Owner bisa lihat payment booking produknya
3. **Users can update own payments** - User bisa update payment mereka sendiri

```sql
-- Contoh policy untuk owner
CREATE POLICY "Owners can view payments for their products"
  ON payments FOR SELECT
  USING (
    booking_id IN (
      SELECT b.id 
      FROM bookings b
      JOIN products p ON b.product_id = p.id
      WHERE p.owner_id = auth.uid()
    )
  );
```

---

### File 2: `supabase_test_payment_flow.sql`
SQL untuk test lengkap payment flow.

**Test Flow:**
1. Create test user (renter & owner)
2. Create test product
3. Create test booking
4. Create test payment (status: pending)
5. Update payment ke paid (simulasi download QR)
6. Verify trigger auto-update booking.payment_status
7. Test RLS: renter bisa lihat? owner bisa lihat?

**Expected Results:**
- ✅ Payment status update dari `pending` → `paid`
- ✅ Booking payment_status auto-update via trigger
- ✅ Renter bisa query payment mereka
- ✅ Owner bisa query payment untuk produk mereka

---

## 📋 Langkah Perbaikan

### Step 1: Fix RLS Policies
```bash
1. Buka Supabase Dashboard
2. Pilih project RentLens
3. Klik "SQL Editor"
4. Copy paste isi file: supabase_fix_payment_rls.sql
5. Klik "Run"
6. Verify: Policy berhasil dibuat tanpa error
```

### Step 2: Test Payment Flow
```bash
1. Masih di SQL Editor
2. Copy paste isi file: supabase_test_payment_flow.sql
3. Klik "Run"
4. Cek hasil query:
   - Initial State: payment_status = pending
   - After Update: payment_status = paid
   - Renter View: 1 row visible
   - Owner View: 1 row visible
```

### Step 3: Test di Flutter App
```bash
1. Login sebagai User A
2. Booking produk dari User B
3. Klik "Pay Now"
4. Klik "Download QR Code"
5. Cek console log:
   📥 ========== PAYMENT UPDATE STARTED ==========
   💳 ========== PAYMENT REPOSITORY UPDATE ==========
   ✅ Payment updated in database
   
6. Login sebagai User B (owner)
7. Buka "Booking Requests"
8. Cek detail booking
9. Harus muncul: Payment Status = "Paid" ✅
```

---

## 🔍 Debug Console Logs

### Saat Download QR (User Peminjam):
```
📥 ========== PAYMENT UPDATE STARTED ==========
   Payment ID: xxx-xxx-xxx
   Order ID: ORDER-xxx
   Booking ID: yyy-yyy-yyy
   Current Status: pending

✅ Mock settlement data prepared
   Data: {transaction_status: settlement, ...}

📝 Updating payment in database...

💳 ========== PAYMENT REPOSITORY UPDATE ==========
   Order ID: ORDER-xxx
   Midtrans Data: {...}
   Transaction Status: settlement
   Determined Status: paid
   Update Data: {status: paid, paid_at: ..., ...}
   Executing UPDATE query...

✅ Payment updated in database
   Response: {id: xxx, status: paid, ...}

🔄 Invalidating providers for sync...
✅ ========== PAYMENT UPDATE COMPLETED ==========
```

### Saat Owner Buka Booking Detail:
```
📦 BOOKING REPOSITORY: Fetching booking with product by ID: yyy
💳 PAYMENT REPOSITORY: Fetching payment for booking: yyy
✅ PAYMENT REPOSITORY: Payment found
   Status: paid
   Paid At: 2025-12-11 10:30:00
```

---

## 🐛 Troubleshooting

### Masalah 1: Error "new row violates row-level security policy"
**Penyebab:** Policy UPDATE tidak mengizinkan user update payment mereka  
**Solusi:** Jalankan `supabase_fix_payment_rls.sql`

### Masalah 2: Owner tetap lihat "No payment record yet"
**Penyebab:** Policy SELECT tidak include owner  
**Solusi:** 
- Jalankan policy `Owners can view payments for their products`
- Pastikan join booking → product → owner_id benar

### Masalah 3: Payment status berubah di UI tapi refresh hilang
**Penyebab:** Update berhasil tapi RLS SELECT tidak allow  
**Solusi:** Cek policy SELECT untuk user dan owner

### Masalah 4: Trigger tidak jalan (booking.payment_status tidak update)
**Penyebab:** Trigger tidak aktif atau error  
**Solusi:**
```sql
-- Cek trigger exists
SELECT * FROM pg_trigger WHERE tgname = 'update_booking_payment_status_trigger';

-- Re-create trigger
DROP TRIGGER IF EXISTS update_booking_payment_status_trigger ON payments;
CREATE TRIGGER update_booking_payment_status_trigger
  AFTER UPDATE ON payments
  FOR EACH ROW
  EXECUTE FUNCTION update_booking_payment_status();
```

---

## ✅ Verification Checklist

- [ ] SQL `supabase_fix_payment_rls.sql` dijalankan tanpa error
- [ ] Test SQL `supabase_test_payment_flow.sql` semua hasil OK
- [ ] Policy "Users can update own payments" exist di Supabase
- [ ] Policy "Owners can view payments for their products" exist
- [ ] User bisa download QR tanpa error RLS
- [ ] Payment status update tersimpan di database
- [ ] Trigger auto-update booking.payment_status bekerja
- [ ] Owner bisa lihat payment status "Paid" di booking detail
- [ ] Console log tidak ada error

---

## 📊 Database Schema Reference

### Table: payments
```sql
id              UUID PRIMARY KEY
booking_id      UUID REFERENCES bookings(id)
order_id        VARCHAR(255) UNIQUE
amount          BIGINT
status          payment_status (pending/paid/failed)
transaction_id  VARCHAR(255)
paid_at         TIMESTAMP
```

### Table: bookings
```sql
id              UUID PRIMARY KEY
user_id         UUID (peminjam)
product_id      UUID
payment_status  payment_status (auto-updated by trigger)
```

### Table: products
```sql
id              UUID PRIMARY KEY
owner_id        UUID (pemilik produk)
```

### Flow:
```
User (peminjam) → Booking → Payment
                    ↓
Product ← Owner (pemilik)
```

### RLS Logic:
- **Peminjam** bisa CRUD payment untuk `booking.user_id = auth.uid()`
- **Owner** bisa READ payment untuk `booking.product_id.owner_id = auth.uid()`

---

## 🚀 Next Steps

1. ✅ Jalankan fix RLS SQL
2. ✅ Test dengan SQL test file
3. ✅ Test di Flutter app
4. ✅ Verify owner bisa lihat payment
5. ✅ Done!
