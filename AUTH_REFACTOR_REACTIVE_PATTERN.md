# 🔧 Authentication Refactor - Reactive Pattern with Riverpod

## Problem Solved

**Issue:** When entering WRONG credentials, the app navigates to Home for a split second, then redirects back to Login with the error message. This indicates premature navigation BEFORE authentication result is confirmed.

**Root Cause:** Navigation logic (`context.go('/home')`) was placed directly inside `onPressed` or repository callbacks, causing race conditions with authentication state changes.

## Solution: Reactive Pattern with AsyncValue

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    NEW ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  UI Layer (LoginScreen)                                      │
│  │                                                            │
│  ├─> Button.onPressed()                                      │
│  │    └─> ONLY calls controller.login()                      │
│  │        ❌ NO context.go()                                  │
│  │        ❌ NO Navigator.push()                              │
│  │                                                            │
│  ├─> ref.listen(authControllerProvider)                      │
│  │    ├─> AsyncData (Success) ──> Navigate to Home          │
│  │    ├─> AsyncError (Failure) ──> Show Error               │
│  │    └─> AsyncLoading ──────────> Show Loading             │
│  │                                                            │
│  └─> ref.watch() for UI state                                │
│                                                               │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Controller Layer (AuthController)                           │
│  │                                                            │
│  ├─> StateNotifier<AsyncValue<User?>>                        │
│  │                                                            │
│  ├─> signInWithEmail()                                       │
│  │    ├─> Set state = AsyncValue.loading()                   │
│  │    ├─> Call repository.signInWithEmail()                  │
│  │    ├─> Success: state = AsyncValue.data(user)            │
│  │    └─> Error: state = AsyncValue.error(error)            │
│  │                                                            │
│  └─> ❌ NO navigation logic here                             │
│                                                               │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Repository Layer (AuthRepository)                           │
│  │                                                            │
│  └─> signInWithEmail() ──> Returns AuthResponse             │
│       └─> ❌ NO state management                              │
│           ❌ NO navigation                                    │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Details

### 1. AuthController (New)

File: `lib/features/auth/providers/auth_controller.dart`

```dart
class AuthController extends StateNotifier<AsyncValue<User?>> {
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    // Set loading
    state = const AsyncValue.loading();

    try {
      final response = await _repository.signInWithEmail(...);
      
      // SUCCESS: Set data state (triggers navigation in UI)
      if (response.user != null) {
        state = AsyncValue.data(response.user);
      }
    } catch (e, stackTrace) {
      // ERROR: Set error state (prevents navigation)
      state = AsyncValue.error(e.toString(), stackTrace);
    }
  }
}
```

**Key Points:**
- ✅ Uses `AsyncValue<User?>` for reactive state
- ✅ Returns `Future<void>` (no navigation logic)
- ✅ Only updates state (loading → data/error)
- ✅ UI reacts to state changes automatically

### 2. LoginScreen (Refactored)

File: `lib/features/auth/presentation/screens/login_screen.dart`

```dart
@override
Widget build(BuildContext context) {
  // REACTIVE PATTERN: Listen and react to state changes
  ref.listen<AsyncValue<User?>>(
    authControllerProvider,
    (previous, next) {
      next.when(
        data: (user) {
          if (user != null) {
            // ✅ Navigate ONLY when AsyncData with user
            context.go('/');
          }
        },
        loading: () {
          // ⏳ Show loading (handled by UI)
        },
        error: (error, stackTrace) {
          // ❌ Show error (stay on login page)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.toString())),
          );
        },
      );
    },
  );

  // Button ONLY calls controller
  ElevatedButton(
    onPressed: () {
      // ✅ ONLY call controller method
      ref.read(authControllerProvider.notifier).signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // ❌ NO context.go() here!
    },
  )
}
```

**Key Points:**
- ✅ `ref.listen()` handles ALL navigation logic
- ✅ Button only calls controller method
- ✅ Error state prevents navigation
- ✅ Success state triggers navigation

### 3. Router Config (Updated)

File: `lib/core/config/router_config.dart`

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    redirect: (context, state) {
      final isAuthenticated = authState.value != null;
      final hasError = authState.hasError;
      final isLoading = authState.isLoading;

      // Priority 1: Error → Stay on auth page
      if (hasError && !isGoingToAuth) {
        return '/auth/login';
      }

      // Priority 2: Loading/Error → Stay on current page
      if (isLoading || hasError) {
        return null;
      }

      // Priority 3: Not authenticated → Login
      if (!isAuthenticated && !isGoingToAuth) {
        return '/auth/login';
      }

      // Priority 4: Authenticated on auth → Home
      if (isAuthenticated && isGoingToAuth) {
        return '/';
      }

      return null;
    },
  );
});
```

## Flow Comparison

### ❌ BEFORE (Wrong - Premature Navigation)

```
User clicks Login
    ↓
Button.onPressed() calls controller
    ↓
Controller sets loading
    ↓
Repository throws error
    ↓
⚡ Auth listener sees old session
    ↓
⚡ State = authenticated (WRONG!)
    ↓
⚡ Router: isAuthenticated=true → Go Home 
    ↓
❌ USER SEES HOME SCREEN (flash)
    ↓
Controller catches error
    ↓
State = error
    ↓
Router: hasError=true → Go Login
    ↓
✅ User back on login with error
```

### ✅ AFTER (Correct - No Premature Navigation)

```
User clicks Login
    ↓
Button.onPressed() ONLY calls controller.signInWithEmail()
    ↓
Controller: state = AsyncValue.loading()
    ↓
ref.listen: AsyncLoading → Show loading indicator
    ↓
Router: isLoading=true → Stay on login ✅
    ↓
Repository: Authentication fails
    ↓
Controller: state = AsyncValue.error("Invalid credentials")
    ↓
ref.listen: AsyncError → Show SnackBar with error
    ↓
Router: hasError=true → Stay on login ✅
    ↓
✅ USER STAYS ON LOGIN PAGE
✅ Error message displayed inline + SnackBar
✅ NO navigation to home
```

### ✅ SUCCESS Flow

```
User clicks Login with correct credentials
    ↓
Button.onPressed() ONLY calls controller.signInWithEmail()
    ↓
Controller: state = AsyncValue.loading()
    ↓
Repository: Authentication succeeds
    ↓
Controller: state = AsyncValue.data(user)
    ↓
ref.listen: AsyncData(user != null) → context.go('/')
    ↓
✅ USER NAVIGATES TO HOME
```

## Files Modified

1. ✅ **NEW:** `lib/features/auth/providers/auth_controller.dart`
   - New controller using `AsyncValue<User?>`
   - Reactive state management
   - No navigation logic

2. ✅ **REFACTORED:** `lib/features/auth/presentation/screens/login_screen.dart`
   - Removed navigation from `onPressed`
   - Added `ref.listen()` for reactive navigation
   - Error handling via SnackBar + inline display

3. ✅ **REFACTORED:** `lib/features/auth/presentation/screens/register_screen.dart`
   - Same reactive pattern as login
   - Uses `ref.listen()` for navigation

4. ✅ **UPDATED:** `lib/core/config/router_config.dart`
   - Now uses `authControllerProvider`
   - Updated redirect logic for `AsyncValue`

## Testing

### Test Scenario 1: Wrong Credentials

**Steps:**
1. Enter wrong email/password
2. Click "Log in"

**Expected Result:**
- ✅ User STAYS on login screen
- ✅ Loading indicator shows briefly
- ✅ Error message appears inline
- ✅ SnackBar shows error
- ✅ NO flash/redirect to home
- ❌ NO premature navigation

### Test Scenario 2: Correct Credentials

**Steps:**
1. Enter correct email/password
2. Click "Log in"

**Expected Result:**
- ✅ Loading indicator shows
- ✅ User navigates to home
- ✅ Smooth transition
- ✅ No error messages

### Test Scenario 3: Empty Fields

**Steps:**
1. Leave fields empty
2. Click "Log in"

**Expected Result:**
- ✅ Form validation errors show
- ✅ No network call
- ✅ Stay on login page

## Benefits of This Pattern

1. **✅ Separation of Concerns**
   - UI only handles display & user input
   - Controller only handles business logic
   - Repository only handles data operations

2. **✅ Reactive & Predictable**
   - State changes drive UI updates
   - No manual state checking
   - Single source of truth

3. **✅ No Race Conditions**
   - Navigation only happens on AsyncData(user)
   - Error state prevents navigation
   - Loading state keeps user on current page

4. **✅ Testable**
   - Controller can be tested independently
   - UI logic is declarative
   - No hidden side effects

5. **✅ Scalable**
   - Easy to add new auth states
   - Easy to add new screens
   - Easy to add new authentication methods

## Key Principles

1. **Never navigate in button callbacks**
   ```dart
   // ❌ WRONG
   onPressed: () async {
     await login();
     context.go('/home'); // DON'T DO THIS
   }

   // ✅ CORRECT
   onPressed: () {
     ref.read(controller.notifier).login();
     // Navigation handled by ref.listen
   }
   ```

2. **Always use ref.listen for navigation**
   ```dart
   // ✅ In build method
   ref.listen(authControllerProvider, (prev, next) {
     next.when(
       data: (user) => user != null ? context.go('/') : null,
       ...
     );
   });
   ```

3. **Controller returns Future<void>**
   ```dart
   // ✅ Controller
   Future<void> signIn() async {
     state = AsyncValue.loading();
     try {
       final user = await repository.signIn();
       state = AsyncValue.data(user);
     } catch (e) {
       state = AsyncValue.error(e);
     }
   }
   ```

## Conclusion

The refactored authentication system now follows proper Riverpod reactive patterns:
- **NO** premature navigation
- **NO** race conditions
- **Predictable** state management
- **Clean** separation of concerns
- **Easy** to test and maintain

This is the **correct way** to handle authentication with Riverpod! 🎉
