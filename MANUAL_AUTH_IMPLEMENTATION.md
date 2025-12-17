# Manual Authentication Implementation Guide

## Overview
This system **completely bypasses Supabase Auth** and uses a custom `users` table with username/password authentication.

## Database Changes

### 1. Run Migration SQL
Execute `supabase_manual_auth_migration.sql` in your Supabase SQL editor.

This will:
- Create custom `users` table (NO connection to `auth.users`)
- Add `register_user()` and `login_user()` functions
- Create demo accounts for testing
- Set up proper RLS policies

### 2. Demo Accounts Created

| Username | Password | Role | Email |
|----------|----------|------|-------|
| admin | admin123hash | admin | admin@demo.com |
| user1 | password123hash | user | user1@demo.com |
| user2 | password123hash | user | user2@demo.com |
| demo | demo123hash | user | (empty) |

**Note:** Passwords are hashed. Implement proper hashing in Flutter (see below).

## Flutter Implementation

### Required Changes

#### 1. Update User Profile Model

File: `lib/features/auth/domain/models/user_profile.dart`

The model should now include `username` and remove `auth.users` references:

```dart
class UserProfile {
  final String id;
  final String username; // NEW - required for login
  final String fullName;
  final String? email; // OPTIONAL - no validation
  final String? phoneNumber;
  final String? avatarUrl;
  final String role;
  final bool isBanned;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  
  // NO passwordHash - never send to frontend
}
```

#### 2. Create Password Hashing Utility

File: `lib/core/utils/password_helper.dart`

```dart
import 'package:crypto/crypto.dart';
import 'dart:convert';

class PasswordHelper {
  /// For demo purposes - simple SHA-256 hash
  /// In production, use bcrypt or similar
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }
  
  /// For stronger security (optional - requires bcrypt package)
  // static String hashPasswordSecure(String password) {
  //   return BCrypt.hashpw(password, BCrypt.gensalt());
  // }
}
```

Add dependency in `pubspec.yaml`:
```yaml
dependencies:
  crypto: ^3.0.3 # For SHA-256 hashing
```

#### 3. Update Authentication Repository

File: `lib/features/auth/data/repositories/auth_repository.dart`

Replace **ALL** Supabase Auth calls with direct database queries:

```dart
class AuthRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;
  
  /// Register new user (NO Supabase Auth)
  Future<UserProfile> registerUser({
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phoneNumber,
  }) async {
    try {
      // Hash password
      final passwordHash = PasswordHelper.hashPassword(password);
      
      // Call database function
      final response = await _supabase.rpc('register_user', params: {
        'p_username': username,
        'p_password_hash': passwordHash,
        'p_full_name': fullName,
        'p_email': email ?? '',
        'p_phone_number': phoneNumber ?? '',
      });
      
      if (response == null) {
        throw Exception('Registrasi gagal');
      }
      
      final result = response as Map<String, dynamic>;
      
      if (result['success'] != true) {
        throw Exception(result['error'] ?? 'Registrasi gagal');
      }
      
      // Parse user data
      final userData = result['user'] as Map<String, dynamic>;
      return UserProfile.fromJson(userData);
      
    } catch (e) {
      throw Exception('Registrasi gagal: $e');
    }
  }
  
  /// Login user (NO Supabase Auth)
  Future<UserProfile> loginUser({
    required String username,
    required String password,
  }) async {
    try {
      // Hash password
      final passwordHash = PasswordHelper.hashPassword(password);
      
      // Call database function
      final response = await _supabase.rpc('login_user', params: {
        'p_username': username,
        'p_password_hash': passwordHash,
      });
      
      if (response == null) {
        throw Exception('Login gagal');
      }
      
      final result = response as Map<String, dynamic>;
      
      if (result['success'] != true) {
        final error = result['error'] ?? 'Username atau password salah';
        throw Exception(error);
      }
      
      // Parse user data
      final userData = result['user'] as Map<String, dynamic>;
      return UserProfile.fromJson(userData);
      
    } catch (e) {
      if (e.toString().contains('ACCOUNT_BANNED')) {
        throw Exception('ACCOUNT_BANNED');
      }
      throw Exception('Login gagal: $e');
    }
  }
  
  /// Logout (just clear local state - no Supabase Auth)
  Future<void> logout() async {
    // NO Supabase Auth signOut
    // Just clear local session if you have one
  }
  
  /// Get current user from local storage/state
  /// (No auth.users.getUser())
  UserProfile? getCurrentUser() {
    // Implement local storage to persist logged-in user
    // Return null if not logged in
    return null;
  }
}
```

#### 4. Update Login Screen

File: `lib/features/auth/presentation/screens/login_screen.dart`

Change form to use **username** instead of email:

```dart
// Replace email field with username field
TextFormField(
  controller: _usernameController, // Changed from _emailController
  decoration: const InputDecoration(
    labelText: 'Username',
    hintText: 'Masukkan username Anda',
    prefixIcon: Icon(Icons.person_outline),
  ),
  enabled: !isLoading,
  validator: (value) {
    if (value?.isEmpty ?? true) {
      return 'Username wajib diisi';
    }
    if (value!.length < 3) {
      return 'Username minimal 3 karakter';
    }
    return null;
  },
),

// Update login handler
Future<void> _handleLogin() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;

  final username = _usernameController.text.trim();
  final password = _passwordController.text.trim();

  // Call manual login (NO Supabase Auth)
  await ref.read(authControllerProvider.notifier).signIn(
    username, // Changed from email
    password,
  );
}
```

#### 5. Update Register Screen

File: `lib/features/auth/presentation/screens/register_screen.dart`

Add username field and remove email verification:

```dart
// Add username controller
final _usernameController = TextEditingController();

// Add username field (BEFORE email field)
TextFormField(
  controller: _usernameController,
  decoration: const InputDecoration(
    labelText: 'Username',
    hintText: 'Pilih username Anda',
    prefixIcon: Icon(Icons.person_outline),
  ),
  enabled: !isLoading,
  validator: (value) {
    if (value?.isEmpty ?? true) {
      return 'Username wajib diisi';
    }
    if (value!.length < 3) {
      return 'Username minimal 3 karakter';
    }
    // Only allow alphanumeric and underscore
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Username hanya boleh huruf, angka, dan underscore';
    }
    return null;
  },
),

// Make email OPTIONAL (remove required validation)
TextFormField(
  controller: _emailController,
  decoration: const InputDecoration(
    labelText: 'Email (opsional)',
    hintText: 'Masukkan email Anda (opsional)',
    prefixIcon: Icon(Icons.email_outlined),
  ),
  keyboardType: TextInputType.emailAddress,
  enabled: !isLoading,
  // NO validator - email is optional
),

// Update register handler
Future<void> _handleRegister() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;

  await ref.read(authControllerProvider.notifier).signUp(
    username: _usernameController.text.trim(),
    password: _passwordController.text.trim(),
    fullName: _fullNameController.text.trim(),
    email: _emailController.text.trim(), // Optional
    phoneNumber: _phoneController.text.trim(), // Optional
  );
}

// REMOVE email verification dialog completely
// NO 'EMAIL_CONFIRMATION_REQUIRED' handling needed
```

#### 6. Update Auth Controller

File: `lib/features/auth/controllers/auth_controller.dart`

```dart
class AuthController extends StateNotifier<AsyncValue<UserProfile?>> {
  final AuthRepository _repository;
  
  AuthController(this._repository) : super(const AsyncValue.data(null));
  
  Future<void> signUp({
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phoneNumber,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final user = await _repository.registerUser(
        username: username,
        password: password,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
      );
      
      state = AsyncValue.data(user);
      
      // NO email verification - user is immediately registered
      
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  Future<void> signIn(String username, String password) async {
    state = const AsyncValue.loading();
    
    try {
      final user = await _repository.loginUser(
        username: username,
        password: password,
      );
      
      state = AsyncValue.data(user);
      
      // Store user locally for persistence
      // TODO: Implement local storage (SharedPreferences/Hive)
      
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  Future<void> signOut() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }
}
```

### Session Management (Optional but Recommended)

Since we're not using Supabase Auth, implement local session storage:

```dart
// lib/core/services/session_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SessionService {
  static const _keyUserId = 'current_user_id';
  static const _keyUserData = 'current_user_data';
  
  Future<void> saveSession(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, user.id);
    await prefs.setString(_keyUserData, jsonEncode(user.toJson()));
  }
  
  Future<UserProfile?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_keyUserData);
    if (userData == null) return null;
    return UserProfile.fromJson(jsonDecode(userData));
  }
  
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserData);
  }
}
```

## Testing

### 1. Test Registration
```dart
// Try registering with minimal data
Username: testdemo
Password: test123
Full Name: Test Demo User
Email: (leave empty)
Phone: (leave empty)
```

### 2. Test Login
```dart
// Use demo account
Username: demo
Password: demo123hash

// Or use the account you just created
Username: testdemo
Password: test123
```

## Key Differences from Supabase Auth

| Feature | Supabase Auth | Manual System |
|---------|---------------|---------------|
| Email Required | ✅ Yes, must be valid | ❌ No, optional string |
| Email Verification | ✅ Required | ❌ None |
| Password Reset | ✅ Via email | ❌ Manual admin reset |
| Username | ❌ Not used | ✅ Primary identifier |
| Registration | Async (email confirm) | Instant |
| Session | Auto-managed | Manual (SharedPreferences) |

## Security Notes (For Production)

Current implementation is **DEMO-GRADE** security:
- Simple SHA-256 hashing (not bcrypt)
- No rate limiting
- No CAPTCHA
- No password complexity enforcement
- No session expiry

For production, you would need:
1. Bcrypt password hashing
2. Rate limiting on login attempts
3. Session tokens with expiry
4. HTTPS only
5. Input sanitization
6. CAPTCHA for registration

## Troubleshooting

### "Function register_user does not exist"
- Run the SQL migration file
- Check Supabase SQL editor for errors

### "Username sudah digunakan"
- Choose a different username
- Check existing users: `SELECT username FROM public.users;`

### Login fails with correct credentials
- Verify password hashing matches:
  ```sql
  SELECT username, password_hash FROM public.users WHERE username = 'demo';
  ```
- Ensure hashing algorithm in Flutter matches database

### RLS Policy denies access
- Check that you've run the full migration SQL
- Verify policies with: `SELECT * FROM pg_policies WHERE tablename = 'users';`

## Migration from Existing Supabase Auth Users

If you have existing users in `auth.users`:

```sql
-- Export existing auth users to new users table
INSERT INTO public.users (id, username, full_name, email, role, created_at)
SELECT 
    id,
    COALESCE(raw_user_meta_data->>'username', split_part(email, '@', 1)) as username,
    COALESCE(raw_user_meta_data->>'full_name', email) as full_name,
    email,
    COALESCE(raw_user_meta_data->>'role', 'user') as role,
    created_at
FROM auth.users
ON CONFLICT (username) DO NOTHING;

-- Note: Migrated users won't be able to login until they set a new password
-- through admin panel or password reset feature
```

## Complete!

Your app now uses **100% manual authentication** with no dependency on Supabase Auth.
