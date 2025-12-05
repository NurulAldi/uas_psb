# Panduan Konfigurasi Supabase Email Authentication

## Masalah yang Terjadi

Ketika user melakukan registrasi, mereka tidak bisa langsung login dan data tidak muncul di database. Ini karena **Supabase secara default mengaktifkan Email Confirmation**.

## Solusi 1: Disable Email Confirmation (Untuk Development)

Jika Anda ingin user bisa langsung login setelah registrasi tanpa perlu konfirmasi email:

### Langkah-langkah:

1. **Buka Supabase Dashboard**
   - Pergi ke: https://supabase.com/dashboard
   - Pilih project Anda: `hyufqtxfjgfcobdsjkjr`

2. **Masuk ke Authentication Settings**
   - Klik menu `Authentication` di sidebar kiri
   - Klik tab `Providers`
   - Cari section `Email`

3. **Disable Email Confirmation**
   - Scroll ke bawah sampai menemukan **"Confirm email"**
   - **Toggle OFF** opsi "Confirm email"
   - Klik **Save**

4. **Restart Aplikasi Flutter**
   ```bash
   flutter run
   ```

### Setelah Disable Email Confirmation:
- ✅ User bisa langsung login setelah registrasi
- ✅ Data user langsung muncul di tabel `auth.users`
- ✅ Tidak perlu cek email untuk konfirmasi

---

## Solusi 2: Enable Email Confirmation (Untuk Production)

Jika Anda ingin menggunakan email confirmation (lebih secure):

### Langkah-langkah:

1. **Pastikan Email Confirmation Enabled**
   - Authentication → Providers → Email
   - **Toggle ON** opsi "Confirm email"
   - Klik **Save**

2. **Konfigurasi Email Templates (Opsional)**
   - Pergi ke `Authentication` → `Email Templates`
   - Edit template "Confirm signup"
   - Customize sesuai kebutuhan

3. **Configure SMTP (Opsional tapi Recommended)**
   - Pergi ke `Project Settings` → `Auth`
   - Scroll ke section "SMTP Settings"
   - Konfigurasi dengan email provider Anda (Gmail, SendGrid, dll)
   - **Catatan**: Tanpa SMTP custom, Supabase menggunakan email service bawaan mereka yang terbatas

### Cara Menggunakan dengan Email Confirmation:

1. **User Register**
   - Isi form registrasi
   - Klik "Create account"
   - Akan muncul pesan: "Please check your email to verify your account"

2. **User Check Email**
   - Buka inbox email yang didaftarkan
   - Cari email dari Supabase (cek spam jika tidak ada)
   - Klik link konfirmasi di email

3. **User Login**
   - Setelah email terkonfirmasi, baru bisa login
   - Data user akan muncul di `auth.users` dengan status `confirmed`

---

## Cek Status User di Supabase Dashboard

### Melihat User yang Terdaftar:

1. Buka **Authentication** → **Users** di Supabase Dashboard
2. Anda akan melihat daftar semua user

### Status User:

- **Confirmed = true**: User sudah verifikasi email, bisa login
- **Confirmed = false**: User belum verifikasi email, tidak bisa login
- **Email Confirmed At**: Timestamp kapan email dikonfirmasi

### Jika User Tidak Muncul:

Kemungkinan penyebabnya:
1. ❌ Error saat registrasi (cek console log)
2. ❌ Email sudah terdaftar sebelumnya
3. ❌ Masalah koneksi ke Supabase
4. ❌ Supabase URL/Key salah di `.env`

---

## Testing Registration & Login

### Test dengan Email Confirmation DISABLED:

```
1. Register:
   Email: test@example.com
   Password: password123
   Full Name: Test User

2. Result:
   ✅ Langsung diarahkan ke Home
   ✅ User authenticated
   ✅ Data muncul di auth.users

3. Logout & Login:
   ✅ Bisa login langsung dengan kredensial yang sama
```

### Test dengan Email Confirmation ENABLED:

```
1. Register:
   Email: test@example.com
   Password: password123
   Full Name: Test User

2. Result:
   ℹ️ Muncul pesan: "Please check your email"
   ℹ️ Diarahkan ke Login page
   ❌ Belum bisa login (harus konfirmasi email dulu)
   ⚠️ Data ada di auth.users tapi confirmed=false

3. Confirm Email:
   📧 Buka email
   🔗 Klik link konfirmasi
   ✅ Status berubah jadi confirmed=true

4. Login:
   ✅ Sekarang bisa login dengan kredensial
```

---

## Troubleshooting

### Problem: "Invalid login credentials" setelah register

**Penyebab**: Email confirmation masih enabled, user belum konfirmasi email

**Solusi**:
1. Disable email confirmation (Solusi 1)
2. ATAU konfirmasi email dulu sebelum login (Solusi 2)

### Problem: User tidak muncul di database

**Penyebab**: Error saat registrasi atau email sudah terdaftar

**Solusi**:
1. Cek console log untuk error message
2. Cek apakah email sudah terdaftar di Supabase
3. Verifikasi `.env` file sudah benar

### Problem: Email konfirmasi tidak diterima

**Penyebab**: Email masuk ke spam atau SMTP belum dikonfigurasi

**Solusi**:
1. Cek folder spam
2. Tunggu beberapa menit (kadang delayed)
3. Konfig custom SMTP untuk production
4. Untuk development, disable email confirmation saja

---

## Recommended Setup

### For Development/Testing:
✅ **Disable Email Confirmation**
- Lebih cepat untuk testing
- Tidak perlu cek email berkali-kali
- Data langsung tersedia

### For Production:
✅ **Enable Email Confirmation**
✅ **Setup Custom SMTP**
✅ **Customize Email Templates**
- Lebih secure
- Verify email ownership
- Professional appearance

---

## Next Steps

1. **Pilih salah satu solusi** (Disable atau Enable email confirmation)
2. **Update Supabase settings** sesuai pilihan
3. **Test registration & login** dengan akun baru
4. **Verify** data muncul di Supabase Dashboard

## Support

Jika masih ada masalah:
1. Cek console log saat register/login
2. Cek Network tab di browser DevTools
3. Pastikan `.env` file terload dengan benar
4. Verify Supabase project settings
