# DEBUG INSTRUCTIONS - Authentication Testing

## Langkah-langkah Testing dengan Logging

### 1. Stop App yang Running
Jika ada app yang masih running, stop dulu dengan menekan `Ctrl+C` di terminal.

### 2. Jalankan App dengan Logging
```bash
flutter run
```

### 3. Perhatikan Console Output Saat App Start

Anda harus melihat output seperti ini:
```
✅ Environment variables loaded successfully
🔍 Checking environment configuration...
   Supabase URL: https://hyufqtxfjgfcobdsjkjr.supabase.co
   Supabase Key: eyJhbGciOiJIUzI1NiIs...
✅ Environment configured correctly
✅ Supabase initialized successfully
```

**Jika tidak muncul "✅ Environment configured correctly":**
- Cek file `.env` ada di root project
- Pastikan isinya benar (URL dan ANON_KEY)
- Restart app

---

## Test 1: Register New Account

### Langkah:
1. Klik "Sign up" atau buka register page
2. Isi form:
   - Full Name: `Test User`
   - Email: `test123@example.com` (gunakan email BARU yang belum pernah didaftar)
   - Password: `password123`
   - Confirm Password: `password123`
3. Klik "Create account"

### Yang Harus Muncul di Console:

```
🔵 REGISTER: Form validation started
✅ REGISTER: Form validation passed
📧 REGISTER: Email = test123@example.com
👤 REGISTER: Name = Test User
🔄 REGISTER: Calling signUpWithEmail...
🔵 AUTH PROVIDER: signUpWithEmail called
🔵 REPOSITORY: Attempting to sign up user: test123@example.com
✅ REPOSITORY: Sign up response received
   User ID: [some-uuid]
   Email: test123@example.com
   Session: Active ATAU Null (Email confirmation required)
📊 REGISTER: Result = success ATAU confirmation_required
```

### Hasil yang Diharapkan:

#### Jika Email Confirmation DISABLED (Recommended):
- ✅ SnackBar hijau: "Account created successfully!"
- ✅ Redirect ke Home page
- ✅ Console: "✅ REGISTER: Success! User authenticated"

#### Jika Email Confirmation ENABLED:
- ℹ️ SnackBar biru: "Please check your email..."
- ℹ️ Redirect ke Login page setelah 2 detik
- ℹ️ Console: "⚠️ REGISTER: Email confirmation required"

---

## Test 2: Login dengan Akun yang Baru Dibuat

### Langkah:
1. Buka login page
2. Isi form:
   - Email: `test123@example.com` (email yang tadi didaftarkan)
   - Password: `password123`
3. Klik "Log in"

### Yang Harus Muncul di Console:

```
🔵 LOGIN: Form validation started
✅ LOGIN: Form validation passed
📧 LOGIN: Email = test123@example.com
🔄 LOGIN: Calling signInWithEmail...
🔵 AUTH PROVIDER: signInWithEmail called
🔄 AUTH PROVIDER: Calling repository signInWithEmail...
🔵 REPOSITORY: Attempting to sign in user: test123@example.com
✅ REPOSITORY: Sign in response received
   User ID: [some-uuid]
   Email: test123@example.com
   Session: Active
✅ AUTH PROVIDER: Setting authenticated state
✅ LOGIN: User authenticated! Navigating to home...
```

### Hasil yang Diharapkan:

#### Jika Email Confirmation DISABLED:
- ✅ Berhasil login
- ✅ Redirect ke Home page
- ✅ Console: "✅ LOGIN: User authenticated!"

#### Jika Email Confirmation ENABLED dan Email Belum Dikonfirmasi:
- ❌ SnackBar merah: "Invalid email or password"
- ❌ Tetap di login page
- ❌ Console: "❌ REPOSITORY: Auth Exception..."

---

## Troubleshooting Berdasarkan Console Output

### Problem 1: Tidak Ada Output Console Sama Sekali

**Penyebab:** Fungsi tidak terpanggil

**Solusi:**
1. Pastikan tombol sudah terhubung dengan benar
2. Restart app dengan `flutter run`
3. Coba lagi

---

### Problem 2: Console Menunjukkan "❌ REPOSITORY: Auth Exception"

**Error Message:** `Invalid login credentials`

**Penyebab:** 
- Email/password salah
- ATAU email belum dikonfirmasi (jika email confirmation enabled)

**Solusi:**
- Register akun baru dengan email yang berbeda
- ATAU disable email confirmation di Supabase Dashboard

---

### Problem 3: Console Menunjukkan "❌ Error initializing Supabase"

**Penyebab:** Supabase URL/Key salah atau tidak terload

**Solusi:**
1. Cek file `.env`:
   ```
   SUPABASE_URL=https://hyufqtxfjgfcobdsjkjr.supabase.co
   SUPABASE_ANON_KEY=eyJhbGci...
   ```
2. Pastikan tidak ada spasi atau karakter aneh
3. Restart app
4. Cek console output saat app start

---

### Problem 4: Register Berhasil tapi Login Gagal

**Console menunjukkan:** 
```
⚠️ REGISTER: Email confirmation required
```

**Penyebab:** Email confirmation enabled di Supabase

**Solusi:**

**Option A - Disable Email Confirmation (Cepat):**
1. Buka Supabase Dashboard
2. Authentication → Providers → Email
3. Toggle OFF "Confirm email"
4. Save
5. Hapus user lama di Authentication → Users
6. Register ulang dengan email baru

**Option B - Konfirmasi Email:**
1. Cek inbox email yang didaftarkan
2. Cari email dari Supabase
3. Klik link konfirmasi
4. Login lagi

---

## Cek Data di Supabase Dashboard

### Setelah Register:

1. Buka: https://supabase.com/dashboard/project/hyufqtxfjgfcobdsjkjr
2. Klik: Authentication → Users
3. Cari email yang baru didaftarkan

### Data yang Harus Ada:

- ✅ User dengan email yang didaftarkan
- ✅ Status: `confirmed` (jika email confirmation disabled) atau `unconfirmed` (jika enabled)
- ✅ User Metadata berisi `full_name`

### Jika User TIDAK ADA:

Kemungkinan penyebab:
1. ❌ Error saat register (cek console untuk error message)
2. ❌ Email sudah terdaftar sebelumnya
3. ❌ Network error
4. ❌ Supabase credentials salah

---

## Quick Checklist

Sebelum testing, pastikan:

- [ ] File `.env` ada di root project
- [ ] `.env` berisi URL dan ANON_KEY yang benar
- [ ] `pubspec.yaml` punya `assets: [.env]`
- [ ] Sudah run `flutter pub get`
- [ ] App di-restart dengan `flutter run`
- [ ] Console output menunjukkan "✅ Environment configured correctly"
- [ ] Console output menunjukkan "✅ Supabase initialized successfully"

---

## Expected Complete Flow (Email Confirmation DISABLED)

```
1. User opens app
   → Console: "✅ Supabase initialized"
   → Redirected to Login page (not authenticated)

2. User clicks "Sign up"
   → Navigate to Register page

3. User fills form and clicks "Create account"
   → Console: "🔵 REGISTER: Form validation started"
   → Console: "✅ REGISTER: Form validation passed"
   → Console: "🔵 REPOSITORY: Attempting to sign up..."
   → Console: "✅ REPOSITORY: Sign up response received"
   → Console: "📊 REGISTER: Result = success"
   → SnackBar: "Account created successfully!"
   → Redirected to Home page
   → User authenticated ✅

4. User can now use the app
   → All protected routes accessible
   → Can logout from profile page

5. User logs out and logs in again
   → Navigate to Login page
   → Fill email and password
   → Console: "🔵 LOGIN: Form validation started"
   → Console: "✅ LOGIN: User authenticated!"
   → Redirected to Home page ✅
```

---

## Yang Harus Dilaporkan Jika Masih Error

Copy paste output console lengkap yang dimulai dari:
1. App start (✅ Environment variables loaded...)
2. Register/Login attempt (🔵 REGISTER/LOGIN: Form validation...)
3. Sampai error terjadi (❌ ...)

Plus screenshot dari:
1. Supabase Dashboard → Authentication → Users
2. Form yang diisi
3. Error message yang muncul
