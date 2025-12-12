# Admin vs User Complete Separation

## 🎯 Konsep Arsitektur

Aplikasi RentLens menerapkan **complete separation** antara admin dan user dengan prinsip:
- **Single Responsibility**: Admin hanya mengakses fitur admin, User hanya mengakses fitur user
- **Role-Based Access Control (RBAC)**: Pemisahan akses berdasarkan role di database
- **Automatic Routing**: Redirect otomatis sesuai role saat login

## 🔐 Flow Login & Routing

### User Biasa Login:
```
Login → Cek role → role = 'user' → Redirect ke Home Screen (/)
                                  → Akses: Browse produk, booking, chat
                                  → TIDAK bisa akses /admin/*
```

### Admin Login:
```
Login → Cek role → role = 'admin' → Redirect ke Admin Dashboard (/admin)
                                   → Akses: User management, reports, statistics
                                   → TIDAK bisa akses halaman user (/, /products, dll)
```

## 📁 Struktur File

### Router Configuration
**File**: `lib/core/config/router_config.dart`

**Logic Penting**:
```dart
// Rule 2: Jika authenticated, cek role
if (isAuthenticated) {
  final isAdmin = profile?.role == 'admin';
  
  // Admin di auth page → /admin
  if (isAdmin && isAuthRoute) return '/admin';
  
  // Admin di halaman user → /admin (paksa redirect)
  if (isAdmin && !isAdminRoute && !isAuthRoute) return '/admin';
  
  // User biasa di auth page → /
  if (!isAdmin && isAuthRoute) return '/';
  
  // User biasa coba akses /admin → / (denied)
  if (!isAdmin && isAdminRoute) return '/';
}
```

### Admin Dashboard
**File**: `lib/features/admin/presentation/screens/admin_dashboard_screen.dart`

**Fitur**:
- ✅ Layout terpisah total dari user
- ✅ Navigation bar khusus admin: Dashboard, Users, Reports
- ✅ AppBar dengan info admin + tombol logout
- ✅ Guard: Double check role sebelum render
- ✅ Logout proper: `authController.signOut()` → `/auth/login`

### Home Screen (User)
**File**: `lib/features/home/presentation/screens/home_screen.dart`

**Perubahan**:
- ❌ **DIHAPUS**: Menu "Dashboard Admin" dari PopupMenu
- ❌ **DIHAPUS**: Handler `admin-dashboard` dari onSelected
- ✅ **RESULT**: User TIDAK bisa navigate ke admin dari UI

## 🛡️ Security Layers

### Layer 1: Router Redirect
- Admin login langsung ke `/admin`
- Admin tidak bisa akses `/`, `/products`, dll
- User tidak bisa akses `/admin`

### Layer 2: UI Guard
- Admin dashboard cek `profile?.role == 'admin'`
- Jika bukan admin, tampilkan "Akses Ditolak"

### Layer 3: Database RLS
- Supabase Row Level Security
- Hanya admin yang bisa query tabel users, reports

## 🔄 Navigation Flow

### Admin Session:
```
/auth/login (input credentials)
     ↓
Check role = 'admin'
     ↓
Redirect to /admin
     ↓
AdminDashboardScreen
├── StatisticsScreen
├── UsersManagementScreen  
└── ReportsManagementScreen
     ↓
Logout → /auth/login
```

### User Session:
```
/auth/login (input credentials)
     ↓
Check role = 'user'
     ↓
Redirect to /
     ↓
HomeScreen
├── Browse Products
├── My Bookings
├── My Listings
└── Profile
     ↓
Logout → /auth/login
```

## 📋 Testing Checklist

### ✅ Admin Login:
- [ ] Login dengan akun admin
- [ ] Otomatis redirect ke `/admin`
- [ ] Tidak ada menu user (Produk, Booking, dll)
- [ ] Hanya ada: Dashboard, Users, Reports
- [ ] Logout berfungsi → kembali ke login

### ✅ User Login:
- [ ] Login dengan akun user biasa
- [ ] Otomatis redirect ke `/`
- [ ] Tidak ada menu "Dashboard Admin"
- [ ] Menu normal: Produk, Booking, Profile
- [ ] Logout berfungsi → kembali ke login

### ✅ Access Control:
- [ ] Admin ketik manual `/` → auto redirect ke `/admin`
- [ ] User ketik manual `/admin` → auto redirect ke `/`
- [ ] Logout dari admin → tidak ada sisa state

## 🎨 UI/UX Best Practices

### Separation Principles:
1. **Different Navigation**: Admin pakai NavigationBar, User pakai AppBar + Body
2. **Different Colors**: Admin bisa pakai accent color berbeda (opsional)
3. **Clear Role Indicator**: AppBar admin tampilkan badge "Administrator"
4. **Separate Logout**: Admin logout terpisah dari user logout flow

### User Experience:
- ✅ Admin tidak bingung dengan menu user
- ✅ User tidak lihat menu yang tidak relevan
- ✅ Transition smooth antara login → dashboard
- ✅ Error handling jelas (Akses Ditolak)

## 🔧 Maintenance

### Menambah Halaman Admin Baru:
1. Buat screen di `lib/features/admin/presentation/screens/`
2. Tambah ke `_screens` di `AdminDashboardScreen`
3. Tambah NavigationDestination baru
4. **TIDAK perlu** update router (sudah guard `/admin/*`)

### Menambah Halaman User Baru:
1. Buat screen seperti biasa
2. Tambah route di `router_config.dart`
3. Pastikan **TIDAK** di path `/admin/*`
4. Automatic guard sudah handle access control

## 🚀 Benefits

1. **Security**: Admin dan user terpisah total
2. **Maintainability**: Code lebih clean, tidak ada if-else role di mana-mana
3. **Scalability**: Mudah tambah role baru (moderator, superadmin)
4. **UX**: User tidak overwhelmed dengan fitur yang tidak relevan
5. **Professional**: Seperti aplikasi production-grade (Shopify, WordPress, dll)

---

**Last Updated**: 2025-12-12
**Author**: Software Engineering Team
**Status**: ✅ Production Ready
