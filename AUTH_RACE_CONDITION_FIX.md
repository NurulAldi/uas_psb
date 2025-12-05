# 🔧 Auth Race Condition Fix

## Masalah yang Diperbaiki

User diarahkan ke halaman HOME selama beberapa saat sebelum dikembalikan ke halaman LOGIN dengan error "Invalid email or password".

## Akar Masalah

**RACE CONDITION** antara error state management dan auth state listener:

1. Login gagal → Exception thrown
2. Provider set error state
3. Provider call `signOut()` (async)
4. **🔥 PROBLEM:** Auth listener triggered sebelum session benar-benar dihapus
5. Listener melihat session lama → Set state ke `authenticated`
6. Router redirect ke home (karena `isAuthenticated = true`)
7. Session akhirnya dihapus → Listener triggered lagi
8. Set state ke `unauthenticated` → Router redirect ke login

**Timeline:**
```
T=0ms:   Login gagal, exception caught
T=10ms:  state = error('Invalid password') ✅
T=20ms:  await signOut() called
T=30ms:  🔥 Listener sees OLD session → authenticated ❌
         → Router redirects to HOME ❌
T=50ms:  signOut complete, session cleared
         → Listener triggered → unauthenticated ✅
         → Router redirects to LOGIN ✅
```

## Solusi yang Diimplementasikan

### 1. **Flag Protection (`_isSettingErrorState`)**
```dart
bool _isSettingErrorState = false;
```
- Flag untuk mencegah listener override error state
- Diaktifkan saat handling error
- Listener check flag sebelum update state

### 2. **Urutan Eksekusi yang Benar**
```dart
// BEFORE (❌ Wrong Order):
state = error(...);
await signOut();

// AFTER (✅ Correct Order):
_isSettingErrorState = true;
await signOut();          // Clear session FIRST
state = error(...);       // Then set error
Future.delayed(...) {     // Reset flag after delay
  _isSettingErrorState = false;
}
```

### 3. **Enhanced Listener Protection**
```dart
if (state.error != null || _isSettingErrorState) {
  return; // Skip listener update
}
```

### 4. **Router Priority Check**
```dart
// PRIORITY 1: If has error, force redirect to auth
if (hasError && !isGoingToAuth) {
  return '/auth/login';
}

// PRIORITY 2: Stay on page if loading or error
if (isLoading || hasError) {
  return null;
}
```

### 5. **Session Clear Delay**
```dart
await _supabase.auth.signOut();
await Future.delayed(const Duration(milliseconds: 50));
```
- Memastikan session benar-benar dihapus sebelum melanjutkan

## Files yang Diubah

1. **`lib/features/auth/providers/auth_provider.dart`**
   - Added `_isSettingErrorState` flag
   - Changed error handling order
   - Enhanced listener protection

2. **`lib/core/config/router_config.dart`**
   - Added priority-based redirect logic
   - Enhanced error state handling

3. **`lib/features/auth/data/repositories/auth_repository.dart`**
   - Added delay after signOut
   - Enhanced logging

## Testing

Test dengan kredensial salah:
- ✅ Error message muncul inline di login screen
- ✅ TIDAK ada redirect ke home
- ✅ User tetap di login screen
- ✅ Error message tetap ditampilkan

## Penjelasan Teknis

### Why Clear Session First?
Dengan clear session terlebih dahulu:
1. Session dihapus SEBELUM error state di-set
2. Listener triggered saat signOut
3. Listener melihat NO session → unauthenticated
4. Router check: `hasError=false, isAuthenticated=false`
5. Stay di login atau redirect ke login (sama-sama OK)
6. Set error state SETELAH session cleared
7. Router check: `hasError=true` → Stay di login ✅

### Why Use Flag?
Flag `_isSettingErrorState` mencegah:
1. Listener override error state yang baru di-set
2. Race condition antara async signOut dan state update
3. Multiple auth state changes dalam waktu singkat

### Why Router Priority?
Priority check memastikan:
1. Error state ALWAYS force redirect ke auth page
2. Tidak ada kemungkinan user lihat home saat ada error
3. Clear hierarchy untuk routing decisions

## Kesimpulan

Perbaikan ini menyelesaikan race condition dengan:
- ✅ Mengubah urutan operasi (signOut first)
- ✅ Menambahkan flag protection
- ✅ Menambahkan delay untuk session cleanup
- ✅ Memperkuat router redirect logic
- ✅ Memastikan error state tidak di-override

User sekarang akan:
- Tetap di login screen saat login gagal
- Melihat error message dengan jelas
- TIDAK mengalami flash ke home screen
