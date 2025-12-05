# Authentication Feature - RentLens

## Overview
Complete authentication feature implementation using Supabase Auth and Riverpod state management.

## Files Created/Modified

### 1. **Data Layer**
- `lib/features/auth/data/repositories/auth_repository.dart`
  - Handles all Supabase authentication operations
  - Methods: `signInWithEmail`, `signUpWithEmail`, `signOut`, `resetPassword`, `updateProfile`
  - Comprehensive error handling with user-friendly messages

### 2. **Domain Layer**
- `lib/features/auth/domain/models/auth_state.dart`
  - Manages authentication state (user, loading, error)
  - Factory methods for different states
  - Immutable state with copyWith method

### 3. **Presentation Layer - Providers**
- `lib/features/auth/providers/auth_provider.dart`
  - `authRepositoryProvider` - Provides AuthRepository instance
  - `authProvider` - Main state notifier for auth operations
  - `currentUserProvider` - Provides current user
  - `isAuthenticatedProvider` - Boolean authentication status
  - Input validation (email format, password length)

### 4. **Presentation Layer - Screens**
- `lib/features/auth/presentation/screens/login_screen.dart`
  - Email/password login with validation
  - Loading states with disabled UI
  - Error display via SnackBar
  - Navigation to register screen
  - Password visibility toggle
  
- `lib/features/auth/presentation/screens/register_screen.dart`
  - Full name, email, phone (optional), password, confirm password
  - Form validation for all fields
  - Password matching validation
  - Loading states
  - Success/error feedback via SnackBars
  - Navigation to login screen

### 5. **Router Configuration**
- `lib/core/config/router_config.dart`
  - Updated to use Riverpod provider pattern
  - `routerProvider` - Main router provider
  - Auth-based redirects (login required for protected routes)
  - Automatic redirect to home when authenticated
  - Auth state change listener for router refresh

### 6. **Main App**
- `lib/main.dart`
  - Updated to use ConsumerWidget
  - Integrated with routerProvider

## Features Implemented

### ✅ Authentication Methods
- [x] Email/Password Sign In
- [x] Email/Password Sign Up
- [x] Sign Out
- [x] Password Reset (repository method)
- [x] Profile Update (repository method)

### ✅ UI Features
- [x] Form validation (email format, password length, required fields)
- [x] Loading states (spinner, disabled buttons)
- [x] Error handling (SnackBar messages)
- [x] Success feedback
- [x] Password visibility toggle
- [x] Password confirmation
- [x] Responsive forms

### ✅ Navigation
- [x] Auto-redirect to login when not authenticated
- [x] Auto-redirect to home when authenticated
- [x] Navigation on successful login/registration
- [x] Back navigation between auth screens

### ✅ State Management
- [x] Riverpod StateNotifier for auth state
- [x] Global auth state accessible throughout app
- [x] Auth state persistence via Supabase
- [x] Auth state change listeners

## Usage

### Sign In
```dart
await ref.read(authProvider.notifier).signInWithEmail(
  email: 'user@example.com',
  password: 'password123',
);
```

### Sign Up
```dart
await ref.read(authProvider.notifier).signUpWithEmail(
  email: 'user@example.com',
  password: 'password123',
  fullName: 'John Doe',
  phoneNumber: '+1234567890', // Optional
);
```

### Sign Out
```dart
await ref.read(authProvider.notifier).signOut();
```

### Check Authentication Status
```dart
final isAuthenticated = ref.watch(isAuthenticatedProvider);
final currentUser = ref.watch(currentUserProvider);
```

### Access Auth State
```dart
final authState = ref.watch(authProvider);
if (authState.isLoading) {
  // Show loading
} else if (authState.error != null) {
  // Show error
} else if (authState.isAuthenticated) {
  // User is logged in
}
```

## Configuration Required

Before using the authentication feature, ensure:

1. **Supabase Configuration**
   - Update `lib/core/config/env_config.dart` with your Supabase credentials:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```

2. **Supabase Auth Settings**
   - Enable Email provider in Supabase Dashboard
   - Configure email templates (optional)
   - Set up redirect URLs for password reset (optional)

## Error Handling

The authentication system handles various error scenarios:

- ❌ Invalid email format
- ❌ Weak password (< 6 characters)
- ❌ Empty fields
- ❌ Password mismatch (registration)
- ❌ Invalid credentials
- ❌ User already exists
- ❌ Network errors
- ❌ Supabase errors

All errors are displayed to users via SnackBars with user-friendly messages.

## Navigation Flow

```
┌─────────────────┐
│   App Start     │
└────────┬────────┘
         │
    ┌────▼────┐
    │ Router  │
    └────┬────┘
         │
    ┌────▼────────────┐
    │ Is Authenticated?│
    └─┬─────────────┬─┘
      │             │
   NO │             │ YES
      │             │
┌─────▼─────┐   ┌───▼──────┐
│ Login Page│   │Home Page │
└─────┬─────┘   └──────────┘
      │
      │ Sign Up
      │
┌─────▼──────────┐
│ Register Page  │
└─────┬──────────┘
      │
      │ Success
      │
┌─────▼──────┐
│ Home Page  │
└────────────┘
```

## Testing

To test the authentication feature:

1. **Test Login**
   - Run the app
   - You'll be redirected to login screen
   - Enter valid credentials
   - Verify navigation to home on success

2. **Test Registration**
   - Click "Sign up" link
   - Fill in all required fields
   - Verify password matching validation
   - Submit form
   - Verify navigation to home on success

3. **Test Validation**
   - Try submitting forms with empty fields
   - Try invalid email formats
   - Try short passwords
   - Try mismatched passwords (registration)

4. **Test Loading States**
   - Observe button spinner during API calls
   - Verify UI is disabled during loading

5. **Test Error Messages**
   - Try logging in with wrong credentials
   - Try registering with existing email
   - Verify error SnackBars appear

## Next Steps

Consider implementing:
- [ ] Forgot password UI
- [ ] Email verification flow
- [ ] Social authentication (Google, Apple)
- [ ] Biometric authentication
- [ ] Session timeout
- [ ] Remember me functionality
- [ ] Profile editing screen

## Dependencies Used

- `supabase_flutter: ^2.3.4` - Supabase client
- `flutter_riverpod: ^2.5.1` - State management
- `go_router: ^14.0.2` - Navigation
- `flutter/material.dart` - UI components

## Notes

- Auth state persists across app restarts via Supabase
- Router automatically handles auth-based redirects
- All passwords must be at least 6 characters (Supabase default)
- Phone number is optional during registration
- User metadata (full_name, phone_number) stored in Supabase user object
