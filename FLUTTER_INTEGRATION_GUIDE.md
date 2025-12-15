# Flutter Integration Guide - Supabase SQL Updates

## 🎯 Overview

After running the updated SQL migrations, your Flutter app needs minor updates to work with the new database structure. This guide covers all required changes.

## ✅ No Changes Required For

- ✅ Existing Supabase Auth users (login/logout/session)
- ✅ Product listing and detail screens
- ✅ Booking flow
- ✅ Payment flow
- ✅ Location-based product queries (same function signature)

## 🔄 Changes Required

### 1. Session Management for Custom Users

**File**: Create new `lib/core/services/custom_auth_service.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomAuthService {
  final SupabaseClient _supabase;
  
  CustomAuthService(this._supabase);
  
  /// Set session for custom user (required for RLS policies)
  Future<void> setSession(String userId) async {
    await _supabase.rpc('set_custom_user_session', params: {
      'user_id': userId,
    });
  }
  
  /// Clear session on logout
  Future<void> clearSession() async {
    await _supabase.rpc('clear_custom_user_session');
  }
  
  /// Check if current session is custom auth
  bool get isCustomAuth {
    // Custom users don't have Supabase Auth session
    return _supabase.auth.currentUser == null && 
           _currentUserId != null;
  }
  
  String? _currentUserId;
  String? get currentUserId => _currentUserId;
  
  void setCurrentUserId(String? id) {
    _currentUserId = id;
  }
}
```

### 2. Password Hashing

**File**: Add to `pubspec.yaml`

```yaml
dependencies:
  bcrypt: ^1.1.3
```

**File**: Create `lib/core/utils/password_hasher.dart`

```dart
import 'package:bcrypt/bcrypt.dart';

class PasswordHasher {
  /// Hash password using bcrypt with cost factor 12
  /// Cost 12 = ~300ms on modern hardware (good security/performance balance)
  static Future<String> hash(String password) async {
    return BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 12));
  }
  
  /// Verify password against hash
  static Future<bool> verify(String password, String hash) async {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (e) {
      return false;
    }
  }
  
  /// Validate password strength
  static String? validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null; // Valid
  }
}
```

### 3. Custom User Repository

**File**: Create `lib/features/auth/data/repositories/custom_auth_repository.dart`

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rentlens/core/utils/password_hasher.dart';
import 'package:rentlens/core/services/custom_auth_service.dart';
import 'package:rentlens/features/auth/domain/models/custom_user.dart';

class CustomAuthRepository {
  final SupabaseClient _supabase;
  final CustomAuthService _authService;
  
  CustomAuthRepository(this._supabase, this._authService);
  
  /// Register new custom user
  Future<CustomUser> register({
    required String username,
    required String password,
    required String fullName,
    String? email,
  }) async {
    // 1. Validate password
    final passwordError = PasswordHasher.validatePassword(password);
    if (passwordError != null) {
      throw Exception(passwordError);
    }
    
    // 2. Hash password
    final passwordHash = await PasswordHasher.hash(password);
    
    // 3. Insert user
    try {
      final response = await _supabase
          .from('custom_users')
          .insert({
            'username': username,
            'password_hash': passwordHash,
            'full_name': fullName,
            'email': email,
            'role': 'user', // Default role
            'is_banned': false,
          })
          .select()
          .single();
      
      final user = CustomUser.fromJson(response);
      
      // 4. Set session
      await _authService.setSession(user.id);
      _authService.setCurrentUserId(user.id);
      
      return user;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Unique constraint violation
        throw Exception('Username already exists');
      }
      rethrow;
    }
  }
  
  /// Login with custom user credentials
  Future<CustomUser> login({
    required String username,
    required String password,
  }) async {
    // 1. Fetch user by username
    final response = await _supabase.rpc(
      'get_custom_user_by_username',
      params: {'p_username': username},
    );
    
    if (response == null || (response as List).isEmpty) {
      throw Exception('Invalid username or password');
    }
    
    final userData = (response as List).first;
    
    // 2. Check if account is locked
    if (userData['locked_until'] != null) {
      final lockedUntil = DateTime.parse(userData['locked_until']);
      if (lockedUntil.isAfter(DateTime.now())) {
        final remainingMinutes = lockedUntil.difference(DateTime.now()).inMinutes;
        throw Exception('Account locked. Try again in $remainingMinutes minutes.');
      }
    }
    
    // 3. Check if banned
    if (userData['is_banned'] == true) {
      throw Exception('This account has been banned. Contact support.');
    }
    
    // 4. Verify password
    final isValid = await PasswordHasher.verify(
      password,
      userData['password_hash'],
    );
    
    if (!isValid) {
      // Increment failed login attempts
      await _supabase.rpc('increment_login_attempts', params: {
        'p_username': username,
      });
      throw Exception('Invalid username or password');
    }
    
    // 5. Update last login
    await _supabase.rpc('update_custom_user_login', params: {
      'p_user_id': userData['id'],
    });
    
    // 6. Fetch full user profile
    final userResponse = await _supabase
        .from('custom_users')
        .select()
        .eq('id', userData['id'])
        .single();
    
    final user = CustomUser.fromJson(userResponse);
    
    // 7. Set session
    await _authService.setSession(user.id);
    _authService.setCurrentUserId(user.id);
    
    return user;
  }
  
  /// Logout custom user
  Future<void> logout() async {
    await _authService.clearSession();
    _authService.setCurrentUserId(null);
  }
  
  /// Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    final response = await _supabase.rpc(
      'username_exists',
      params: {'p_username': username},
    );
    return !(response as bool);
  }
}
```

### 4. Custom User Model

**File**: Create `lib/features/auth/domain/models/custom_user.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'custom_user.freezed.dart';
part 'custom_user.g.dart';

@freezed
class CustomUser with _$CustomUser {
  const factory CustomUser({
    required String id,
    required String username,
    required String fullName,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    @Default('user') String role,
    @Default(false) bool isBanned,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    DateTime? locationUpdatedAt,
    DateTime? lastLoginAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _CustomUser;

  factory CustomUser.fromJson(Map<String, dynamic> json) =>
      _$CustomUserFromJson(json);
}
```

### 5. Update Auth Controller

**File**: Modify `lib/features/auth/controllers/auth_controller.dart`

```dart
// Add to existing AuthController

class AuthController extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository _authRepository;
  final CustomAuthRepository _customAuthRepository;
  final CustomAuthService _customAuthService;
  
  // ... existing code ...
  
  /// Check if user is logged in (either Supabase Auth or Custom)
  bool get isAuthenticated {
    return _authRepository.currentUser != null || 
           _customAuthService.currentUserId != null;
  }
  
  /// Get current user ID (works for both auth types)
  String? get currentUserId {
    return _authRepository.currentUser?.id ?? 
           _customAuthService.currentUserId;
  }
  
  /// Login with custom credentials
  Future<void> loginCustomUser({
    required String username,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _customAuthRepository.login(
        username: username,
        password: password,
      );
      state = AsyncValue.data(null); // Custom users don't have Supabase User
      ref.invalidate(currentUserProfileProvider); // Refresh profile
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Register custom user
  Future<void> registerCustomUser({
    required String username,
    required String password,
    required String fullName,
    String? email,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _customAuthRepository.register(
        username: username,
        password: password,
        fullName: fullName,
        email: email,
      );
      state = AsyncValue.data(null);
      ref.invalidate(currentUserProfileProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// Logout (works for both auth types)
  @override
  Future<void> logout() async {
    if (_customAuthService.isCustomAuth) {
      await _customAuthRepository.logout();
    } else {
      await _authRepository.logout();
    }
    state = const AsyncValue.data(null);
  }
}
```

### 6. Update Profile Provider

**File**: Modify `lib/features/auth/providers/profile_provider.dart`

```dart
final currentUserProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authControllerProvider);
  final customAuthService = ref.watch(customAuthServiceProvider);
  
  // For Supabase Auth users
  if (authState.value != null) {
    final userId = authState.value!.id;
    return supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => rows.isEmpty ? null : UserProfile.fromJson(rows.first));
  }
  
  // For custom users
  if (customAuthService.currentUserId != null) {
    return supabase
        .from('custom_users')
        .stream(primaryKey: ['id'])
        .eq('id', customAuthService.currentUserId!)
        .map((rows) {
          if (rows.isEmpty) return null;
          final data = rows.first;
          // Convert custom_user to UserProfile format
          return UserProfile.fromJson({
            ...data,
            'auth_type': 'custom',
          });
        });
  }
  
  // Not logged in
  return Stream.value(null);
});
```

## 🧪 Testing Checklist

### Test Custom User Flow

```dart
// 1. Test registration
final user = await customAuthRepository.register(
  username: 'testuser',
  password: 'TestPass123!',
  fullName: 'Test User',
  email: 'test@example.com',
);
print('Registered: ${user.username}');

// 2. Test logout
await customAuthRepository.logout();

// 3. Test login
final loggedInUser = await customAuthRepository.login(
  username: 'testuser',
  password: 'TestPass123!',
);
print('Logged in: ${loggedInUser.username}');

// 4. Test username availability
final isAvailable = await customAuthRepository.isUsernameAvailable('newuser');
print('Username available: $isAvailable');

// 5. Test failed login (should lock after 5 attempts)
for (int i = 0; i < 6; i++) {
  try {
    await customAuthRepository.login(
      username: 'testuser',
      password: 'wrongpassword',
    );
  } catch (e) {
    print('Attempt ${i + 1}: $e');
  }
}
```

### Test Location Updates

```dart
// No changes needed - existing code works
await supabase.from('profiles').update({
  'latitude': -6.9175,
  'longitude': 107.6191,
  'city': 'Bandung',
}).eq('id', userId);

// The location_point geography column is auto-updated by trigger
```

### Test Nearby Products

```dart
// No changes needed - existing code works
final products = await productRepository.getNearbyProducts(
  latitude: -6.9175,
  longitude: 107.6191,
  radiusKm: 20.0,
  searchText: 'canon',
  category: 'DSLR',
);
print('Found ${products.length} nearby products');
```

## 🔐 Security Considerations

### Password Storage
```dart
// ❌ NEVER do this
final password = 'plaintext'; // WRONG!

// ✅ ALWAYS hash before storage
final hash = await PasswordHasher.hash(password); // CORRECT!
```

### Session Management
```dart
// ✅ Always set session after login
await customAuthService.setSession(user.id);

// ✅ Always clear session on logout
await customAuthService.clearSession();
```

### Rate Limiting
```dart
// Implement in your login screen
class LoginScreen extends StatefulWidget {
  // Add rate limiting to prevent brute force
  final _rateLimiter = RateLimiter(
    maxAttempts: 5,
    duration: Duration(minutes: 15),
  );
  
  Future<void> _login() async {
    if (!_rateLimiter.isAllowed()) {
      showError('Too many attempts. Try again later.');
      return;
    }
    
    try {
      await ref.read(authControllerProvider.notifier).loginCustomUser(
        username: _usernameController.text,
        password: _passwordController.text,
      );
      _rateLimiter.reset(); // Success - reset counter
    } catch (e) {
      _rateLimiter.recordAttempt(); // Failure - increment counter
      showError(e.toString());
    }
  }
}
```

## 📊 Migration Timeline

### Phase 1: Backend (Day 1)
- [x] Run SQL migrations on Supabase
- [x] Verify functions work
- [x] Test with sample data

### Phase 2: Flutter Updates (Day 2)
- [ ] Add bcrypt dependency
- [ ] Create CustomAuthService
- [ ] Create CustomAuthRepository
- [ ] Create CustomUser model
- [ ] Update AuthController
- [ ] Update ProfileProvider

### Phase 3: UI Updates (Day 3)
- [ ] Add custom registration screen
- [ ] Add username/password login option
- [ ] Update logout to handle both auth types
- [ ] Add "Login with Username" button

### Phase 4: Testing (Day 4)
- [ ] Test custom user registration
- [ ] Test custom user login
- [ ] Test session persistence
- [ ] Test RLS policies
- [ ] Test location updates
- [ ] Test nearby products query

### Phase 5: Deployment (Day 5)
- [ ] Deploy to staging
- [ ] User acceptance testing
- [ ] Monitor for errors
- [ ] Deploy to production

## 🆘 Troubleshooting

### Error: "RPC function not found"
**Solution**: Make sure you ran the SQL migrations first.

### Error: "Session variable not set"
**Solution**: Call `customAuthService.setSession(userId)` after login.

### Error: "Password hash mismatch"
**Solution**: Make sure you're using bcrypt with the same cost factor (12).

### Error: "Geography column is null"
**Solution**: The trigger only runs on INSERT/UPDATE. Update existing rows:
```sql
UPDATE profiles SET latitude = latitude WHERE latitude IS NOT NULL;
UPDATE custom_users SET latitude = latitude WHERE latitude IS NOT NULL;
```

## ✅ Final Checklist

- [ ] SQL migrations run successfully on Supabase
- [ ] PostGIS extension enabled
- [ ] bcrypt dependency added to Flutter project
- [ ] CustomAuthService created and registered with Riverpod
- [ ] CustomAuthRepository created
- [ ] CustomUser model created with freezed
- [ ] AuthController updated to handle both auth types
- [ ] ProfileProvider updated to handle custom users
- [ ] Registration screen updated
- [ ] Login screen updated with username option
- [ ] All tests passing
- [ ] Security review completed

---

**Integration Status**: Ready for implementation ✅  
**Estimated Time**: 4-5 days  
**Breaking Changes**: None (backward compatible)  
**Required Dependencies**: `bcrypt: ^1.1.3`
