# Analisis dan Implementasi Login Supabase yang Benar untuk RentLens

## 📋 ANALISIS MASALAH SEBELUMNYA

### Masalah Utama yang Terjadi:

1. **Race Conditions**
   - Controller dan listener sama-sama update state
   - Double state update menyebabkan conflict
   - Timing issue antara manual state set dan listener

2. **Error State Management**
   - Mengakses `.value` pada `AsyncError` menyebabkan crash
   - Error state terbawa ke page lain saat navigation
   - Router logic tidak handle error dengan benar

3. **Navigation Issues**
   - Manual navigation di listener berbenturan dengan router
   - Error pada register page redirect ke login page
   - Tidak ada clear feedback untuk user

4. **Validation Issues**
   - Email regex terlalu strict/loose
   - Supabase email validation berbeda dengan client-side
   - Input tidak di-trim sebelum validation

## ✅ IMPLEMENTASI YANG BENAR

### Prinsip Dasar:

1. **Single Source of Truth**: Auth state hanya di-update oleh satu source
2. **Clear Separation**: Controller logic terpisah dari UI logic
3. **Safe State Access**: Selalu gunakan safe pattern untuk akses AsyncValue
4. **Simple Flow**: Satu arah data flow tanpa circular updates

---

## 🏗️ ARSITEKTUR YANG BENAR

```
┌─────────────────────────────────────────────────────────┐
│                    SUPABASE AUTH                         │
│  (Single Source of Truth untuk Auth State)              │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ auth.onAuthStateChange
                     │
         ┌───────────▼──────────────┐
         │  AuthController          │
         │  (StateNotifier)         │
         │  - Listen ke Supabase    │
         │  - Update state ONLY     │
         │  - NO manual navigation  │
         └───────────┬──────────────┘
                     │
                     │ AsyncValue<User?>
                     │
         ┌───────────▼──────────────┐
         │  Router (GoRouter)       │
         │  - Watch auth state      │
         │  - Handle redirects      │
         │  - NO business logic     │
         └───────────┬──────────────┘
                     │
                     │ Routes
                     │
         ┌───────────▼──────────────┐
         │  UI Screens              │
         │  - Display state         │
         │  - Call controller       │
         │  - Handle user feedback  │
         └──────────────────────────┘
```

---

## 📝 IMPLEMENTASI STEP-BY-STEP

### STEP 1: Setup Supabase (Development Mode)

#### 1.1. Database Setup
```sql
-- Jalankan supabase_setup.sql yang sudah ada
-- Pastikan sudah ada:
-- ✓ Table profiles
-- ✓ Table products  
-- ✓ Table bookings
-- ✓ RLS Policies (permissive untuk development)
-- ✓ Trigger untuk auto-create profile
```

#### 1.2. Supabase Auth Settings (PENTING!)

**Buka Supabase Dashboard → Authentication → Providers:**

1. **Enable Email Provider**
   - ✅ Enable Email provider
   
2. **DISABLE Email Confirmation (untuk development)**
   - ❌ Confirm email: **OFF**
   - Alasan: User bisa langsung login tanpa cek email
   
3. **Allow Any Email Domain (untuk development)**
   - Tidak ada restricting email domains
   - User bisa daftar dengan email apapun (test@test.com juga OK)

4. **Password Requirements**
   - Minimum length: 6 characters (default)
   - Tidak perlu special characters untuk development

**Buka Supabase Dashboard → Authentication → URL Configuration:**

1. **Site URL**: `http://localhost:3000` (atau URL app Anda)
2. **Redirect URLs**: Tambahkan jika perlu untuk web

---

### STEP 2: Environment Configuration

```dart
// lib/core/config/env_config.dart
class EnvConfig {
  static String get supabaseUrl => 
    dotenv.env['SUPABASE_URL'] ?? '';
  
  static String get supabaseAnonKey => 
    dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
```

```env
# .env file
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
```

---

### STEP 3: Auth Controller (Clean Implementation)

```dart
// lib/features/auth/providers/auth_controller.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuthController extends StateNotifier<AsyncValue<supabase.User?>> {
  final AuthRepository _repository;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthController(this._repository) : super(const AsyncValue.loading()) {
    _initializeAuth();
  }

  /// Initialize: Check current user + start listening
  void _initializeAuth() {
    final currentUser = _repository.currentUser;
    if (currentUser != null) {
      state = AsyncValue.data(currentUser);
    } else {
      state = const AsyncValue.data(null);
    }
    _listenToAuthChanges();
  }

  /// CRITICAL: Only source of state updates
  void _listenToAuthChanges() {
    _authSubscription = _repository.authStateChanges.listen(
      (event) {
        if (event.session != null) {
          // User logged in
          state = AsyncValue.data(event.session!.user);
        } else {
          // User logged out
          state = const AsyncValue.data(null);
        }
      },
      onError: (error) {
        state = AsyncValue.error(error, StackTrace.current);
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Sign in - NO state update here, listener handles it
  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    
    try {
      await _repository.signInWithEmail(
        email: email.trim(),
        password: password.trim(),
      );
      // State akan di-update oleh listener
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Sign up - NO state update here, listener handles it
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    state = const AsyncValue.loading();
    
    try {
      final response = await _repository.signUpWithEmail(
        email: email.trim(),
        password: password.trim(),
        fullName: fullName.trim(),
        phoneNumber: phoneNumber?.trim(),
      );
      
      // Check if email confirmation required
      if (response.user != null && response.session == null) {
        // Email confirmation required
        state = AsyncValue.error(
          'EMAIL_CONFIRMATION_REQUIRED',
          StackTrace.current,
        );
      }
      // Else: listener will update state
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Sign out - NO state update here, listener handles it
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    
    try {
      await _repository.signOut();
      // State akan di-update oleh listener
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Clear error state manually
  void clearError() {
    if (state.hasError) {
      // Reset to unauthenticated state
      state = const AsyncValue.data(null);
    }
  }
}

// Provider
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<supabase.User?>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});
```

---

### STEP 4: Router (Simple Redirect Logic)

```dart
// lib/core/config/router_config.dart

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Safe access to auth state
      final authState = ref.read(authControllerProvider);
      
      final isAuthenticated = authState.maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );
      
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      
      // Simple rules:
      // 1. If loading, stay on current page
      if (authState.isLoading) {
        return null;
      }
      
      // 2. If authenticated, can't go to auth pages
      if (isAuthenticated && isAuthRoute) {
        return '/';
      }
      
      // 3. If not authenticated, must go to auth pages
      if (!isAuthenticated && !isAuthRoute) {
        return '/auth/login';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      // ... other routes
    ],
  );
});
```

---

### STEP 5: Login Screen (Clean UI)

```dart
// lib/features/auth/presentation/screens/login_screen.dart

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    await ref.read(authControllerProvider.notifier).signIn(
      _emailController.text,
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    
    // Listen to auth state for error display
    ref.listen<AsyncValue<supabase.User?>>(
      authControllerProvider,
      (previous, next) {
        // Only show error, router handles navigation
        if (next.hasError && mounted) {
          final error = next.error.toString();
          if (error != 'EMAIL_CONFIRMATION_REQUIRED') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        }
      },
    );

    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Email field
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Email required';
                }
                // Simple email check
                if (!value!.contains('@')) {
                  return 'Invalid email';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Password field
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              obscureText: _obscurePassword,
              enabled: !isLoading,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Password required';
                }
                if (value!.length < 6) {
                  return 'Password min 6 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Login button
            ElevatedButton(
              onPressed: isLoading ? null : _handleLogin,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Login'),
            ),
            
            const SizedBox(height: 16),
            
            // Register link
            TextButton(
              onPressed: isLoading 
                  ? null 
                  : () => context.go('/auth/register'),
              child: const Text('Don\'t have account? Register'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

### STEP 6: Register Screen (with Email Confirmation Handling)

```dart
// lib/features/auth/presentation/screens/register_screen.dart

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    await ref.read(authControllerProvider.notifier).signUp(
      email: _emailController.text,
      password: _passwordController.text,
      fullName: _fullNameController.text,
      phoneNumber: _phoneController.text.isNotEmpty 
          ? _phoneController.text 
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    
    // Listen for email confirmation requirement
    ref.listen<AsyncValue<supabase.User?>>(
      authControllerProvider,
      (previous, next) {
        if (next.hasError && mounted) {
          final error = next.error.toString();
          
          if (error == 'EMAIL_CONFIRMATION_REQUIRED') {
            // Show dialog for email confirmation
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Verify Your Email'),
                content: Text(
                  'Please check ${_emailController.text} to verify your account.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/auth/login');
                    },
                    child: const Text('Go to Login'),
                  ),
                ],
              ),
            );
          } else {
            // Show error snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error)),
            );
          }
        }
      },
    );

    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Full Name
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
              enabled: !isLoading,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Name required';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Email required';
                }
                if (!value!.contains('@')) {
                  return 'Invalid email';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Phone (optional)
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number (optional)',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              enabled: !isLoading,
            ),
            
            const SizedBox(height: 16),
            
            // Password
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              obscureText: _obscurePassword,
              enabled: !isLoading,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Password required';
                }
                if (value!.length < 6) {
                  return 'Password min 6 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Confirm Password
            TextFormField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword 
                        ? Icons.visibility 
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() => 
                      _obscureConfirmPassword = !_obscureConfirmPassword
                    );
                  },
                ),
              ),
              obscureText: _obscureConfirmPassword,
              enabled: !isLoading,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return 'Please confirm password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Register button
            ElevatedButton(
              onPressed: isLoading ? null : _handleRegister,
              child: isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Register'),
            ),
            
            const SizedBox(height: 16),
            
            // Login link
            TextButton(
              onPressed: isLoading 
                  ? null 
                  : () => context.go('/auth/login'),
              child: const Text('Already have account? Login'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🧪 TESTING SCENARIOS

### Scenario 1: Registration dengan Auto-Login (Email Confirmation OFF)

```
1. User input:
   - Email: test@example.com
   - Password: password123
   - Full Name: Test User

2. Expected flow:
   ✅ Loading state shown
   ✅ Supabase create user
   ✅ Supabase auto-login user
   ✅ Listener detect auth state change
   ✅ State updated to authenticated
   ✅ Router detect authentication
   ✅ Auto redirect to home
   ✅ User can immediately use app

3. Database check:
   ✅ User in auth.users (confirmed=true)
   ✅ Profile in profiles table
```

### Scenario 2: Registration dengan Email Confirmation (Email Confirmation ON)

```
1. User input:
   - Email: test@example.com
   - Password: password123
   - Full Name: Test User

2. Expected flow:
   ✅ Loading state shown
   ✅ Supabase create user
   ✅ NO auto-login
   ✅ State set to error: EMAIL_CONFIRMATION_REQUIRED
   ✅ Dialog shown: "Verify Your Email"
   ✅ User click "Go to Login"
   ✅ Navigate to login page
   ❌ User cannot login yet

3. Database check:
   ✅ User in auth.users (confirmed=false)
   ❌ Cannot login until email confirmed

4. After email confirmation:
   ✅ User click link in email
   ✅ confirmed=true
   ✅ Now can login
```

### Scenario 3: Login dengan Correct Credentials

```
1. User input:
   - Email: test@example.com
   - Password: password123

2. Expected flow:
   ✅ Loading state shown
   ✅ Supabase authenticate user
   ✅ Listener detect auth state change
   ✅ State updated to authenticated
   ✅ Router detect authentication
   ✅ Auto redirect to home
   ✅ User can use app

3. State check:
   ✅ authState.value = User object
   ✅ isAuthenticated = true
   ✅ currentUser != null
```

### Scenario 4: Login dengan Wrong Credentials

```
1. User input:
   - Email: test@example.com
   - Password: wrongpassword

2. Expected flow:
   ✅ Loading state shown
   ✅ Supabase reject authentication
   ✅ Error thrown
   ✅ State set to AsyncError
   ✅ Listener detect error
   ✅ SnackBar shown: "Invalid credentials"
   ✅ Stay on login page
   ✅ User can try again

3. State check:
   ✅ authState.hasError = true
   ✅ isAuthenticated = false
   ✅ currentUser = null
```

### Scenario 5: Logout

```
1. User click logout button

2. Expected flow:
   ✅ Loading state shown
   ✅ Supabase sign out
   ✅ Listener detect auth state change
   ✅ State updated to unauthenticated
   ✅ Router detect no authentication
   ✅ Auto redirect to login
   ✅ User must login again

3. State check:
   ✅ authState.value = null
   ✅ isAuthenticated = false
   ✅ currentUser = null
```

---

## 🔒 SECURITY CONSIDERATIONS

### Development Mode:
- ✅ Email confirmation OFF - untuk kemudahan testing
- ✅ Accept any email domain
- ✅ Permissive RLS policies
- ✅ Simple password requirements (6 chars)

### Production Mode:
- ✅ Email confirmation ON
- ✅ Custom SMTP untuk email
- ✅ Strict RLS policies
- ✅ Strong password requirements
- ✅ Rate limiting
- ✅ CAPTCHA on registration
- ✅ Email domain whitelisting (opsional)

---

## 📊 STATE FLOW DIAGRAM

```
┌─────────────────┐
│  App Start      │
└────────┬────────┘
         │
    ┌────▼────────────────┐
    │ AuthController.init │
    │ - Check currentUser │
    │ - Start listener    │
    └────────┬────────────┘
             │
        ┌────▼────┐
        │ Router  │
        └────┬────┘
             │
    ┌────────▼──────────┐
    │ isAuthenticated?  │
    └───┬───────────┬───┘
        │           │
      NO│           │YES
        │           │
    ┌───▼────┐  ┌───▼────┐
    │ Login  │  │  Home  │
    └───┬────┘  └────────┘
        │
        │ signIn()
        │
    ┌───▼─────────────┐
    │ Repository      │
    │ signInWithEmail │
    └───┬─────────────┘
        │
        │ Success
        │
    ┌───▼──────────────┐
    │ Supabase Auth    │
    │ onAuthStateChange│
    └───┬──────────────┘
        │
        │ Event
        │
    ┌───▼────────────┐
    │ Listener       │
    │ Update State   │
    └───┬────────────┘
        │
    ┌───▼────────┐
    │ Router     │
    │ Redirect → │
    └───┬────────┘
        │
    ┌───▼────┐
    │  Home  │
    └────────┘
```

---

## ✅ CHECKLIST IMPLEMENTASI

### Setup Supabase:
- [ ] Run supabase_setup.sql
- [ ] Verify tables created
- [ ] Check RLS policies
- [ ] Configure auth settings
- [ ] Disable email confirmation (dev)
- [ ] Test dengan Supabase dashboard

### Code Implementation:
- [ ] Setup env_config.dart
- [ ] Implement AuthRepository
- [ ] Implement AuthController
- [ ] Update RouterConfig
- [ ] Create LoginScreen
- [ ] Create RegisterScreen
- [ ] Add logout button (HomeScreen/ProfileScreen)

### Testing:
- [ ] Test registration (auto-login)
- [ ] Test registration (email confirmation)
- [ ] Test login (correct credentials)
- [ ] Test login (wrong credentials)
- [ ] Test logout
- [ ] Test router redirects
- [ ] Test error handling
- [ ] Test loading states

### Production Ready:
- [ ] Enable email confirmation
- [ ] Setup custom SMTP
- [ ] Update RLS policies (strict)
- [ ] Add rate limiting
- [ ] Add error logging
- [ ] Add analytics
- [ ] Security audit

---

## 📚 REFERENSI

1. **Supabase Auth Documentation**
   - https://supabase.com/docs/guides/auth

2. **Flutter Riverpod Best Practices**
   - https://riverpod.dev/docs/concepts/reading

3. **GoRouter with Riverpod**
   - https://codewithandrea.com/articles/flutter-authentication-gorouter-riverpod/

4. **AsyncValue Pattern**
   - https://riverpod.dev/docs/concepts/reading#using-asyncvalue

---

## 🎯 KEY TAKEAWAYS

### DO:
✅ Single source of truth (Supabase auth stream)
✅ Listener updates state, NOT manual updates
✅ Router handles navigation, NOT controller
✅ Use `maybeWhen` for safe AsyncValue access
✅ Trim inputs before validation
✅ Clear error messages for users
✅ Simple, predictable flow

### DON'T:
❌ Update state manually after async operations
❌ Navigate from controller or listener
❌ Access `.value` directly on AsyncValue
❌ Mix business logic in router
❌ Ignore loading states
❌ Have circular state updates
❌ Overcomplicate the flow

---

## 💡 TROUBLESHOOTING

### Issue: User tidak bisa login setelah register
**Solution**: Disable email confirmation di Supabase Dashboard

### Issue: Error "Invalid email"
**Solution**: Supabase mungkin reject format email, coba email valid (@gmail.com)

### Issue: State stuck di loading
**Solution**: Check listener di-dispose dengan benar, check Supabase connection

### Issue: Router tidak redirect
**Solution**: Verify router watching auth state dengan benar

### Issue: Error terbawa ke page lain
**Solution**: Gunakan `maybeWhen` untuk safe access, don't force redirect on error

---

Implementasi ini mengikuti Flutter best practices dan Supabase recommendations untuk authentication yang robust, maintainable, dan user-friendly.
