import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/auth/data/repositories/auth_repository.dart';
import 'package:rentlens/features/auth/domain/models/auth_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Auth State Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  bool _isSettingErrorState = false;

  AuthNotifier(this._repository) : super(AuthState.initial()) {
    _init();
  }

  /// Initialize auth state
  void _init() {
    final currentUser = _repository.currentUser;
    if (currentUser != null) {
      state = AuthState.authenticated(currentUser);
    }

    // Listen to auth state changes
    _repository.authStateChanges.listen((event) {
      // CRITICAL: Don't override error state from listener
      // This prevents auth events (like signOut) from clearing error messages
      if (state.error != null || _isSettingErrorState) {
        print(
            '⚠️ AUTH PROVIDER: Skipping auth state change - preserving error state (error: ${state.error}, isSettingError: $_isSettingErrorState)');
        return;
      }

      if (event.session != null) {
        print('✅ AUTH PROVIDER: Auth listener detected active session');
        state = AuthState.authenticated(event.session!.user);
      } else {
        print('🔓 AUTH PROVIDER: Auth listener detected no session');
        state = AuthState.unauthenticated();
      }
    });
  }

  /// Sign in with email and password
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      print('🔵 AUTH PROVIDER: signInWithEmail called');

      // Validate inputs
      if (email.isEmpty || password.isEmpty) {
        print('❌ AUTH PROVIDER: Empty fields');
        state = AuthState.error('Please fill in all fields');
        return;
      }

      if (!_isValidEmail(email)) {
        print('❌ AUTH PROVIDER: Invalid email format');
        state = AuthState.error('Please enter a valid email address');
        return;
      }

      print('🔄 AUTH PROVIDER: Setting loading state...');
      state = AuthState.loading();

      print('🔄 AUTH PROVIDER: Calling repository signInWithEmail...');
      final response = await _repository.signInWithEmail(
        email: email,
        password: password,
      );

      print('📦 AUTH PROVIDER: Response received - User: ${response.user?.id}');
      if (response.user != null && response.session != null) {
        print(
            '✅ AUTH PROVIDER: Login successful, authStateChanges listener will update state');
        // Note: Don't set state here, let the authStateChanges listener handle it
        // This prevents race condition with the listener
      } else {
        print('❌ AUTH PROVIDER: No user or session in response');
        state = AuthState.error('Failed to sign in');
      }
    } catch (e) {
      print('❌ AUTH PROVIDER: Exception caught = ${e.toString()}');
      print('🔴 AUTH PROVIDER: Clearing session FIRST (before setting error)');

      // CRITICAL FIX: Clear session FIRST to prevent race condition
      // Set flag to prevent listener from overriding error state
      _isSettingErrorState = true;

      try {
        // Clear any existing session synchronously if possible
        await _repository.signOut();
        print('✅ AUTH PROVIDER: Session cleared successfully');
      } catch (signOutError) {
        print('⚠️ AUTH PROVIDER: Error during signOut: $signOutError');
        // Continue to set error state even if signOut fails
      }

      // Now set error state - listener won't override due to flag
      state = AuthState(
        user: null,
        isLoading: false,
        error: e.toString(),
      );

      print(
          '📊 AUTH PROVIDER: Error state set - error: ${state.error}, isAuthenticated: ${state.isAuthenticated}');

      // Reset flag after a small delay to allow state to stabilize
      Future.delayed(const Duration(milliseconds: 100), () {
        _isSettingErrorState = false;
        print('🔓 AUTH PROVIDER: Error state flag cleared');
      });
    }
  }

  /// Sign up with email and password
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    try {
      // Validate inputs
      if (email.isEmpty || password.isEmpty || fullName.isEmpty) {
        state = AuthState.error('Please fill in all required fields');
        return null;
      }

      if (!_isValidEmail(email)) {
        state = AuthState.error('Please enter a valid email address');
        return null;
      }

      if (password.length < 6) {
        state = AuthState.error('Password must be at least 6 characters');
        return null;
      }

      state = AuthState.loading();

      final response = await _repository.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
      );

      if (response.user != null) {
        // Check if email confirmation is required
        final session = response.session;
        if (session != null) {
          // Auto-confirmed, user can login immediately
          state = AuthState.authenticated(response.user!);
          return 'success';
        } else {
          // Email confirmation required
          state = AuthState.unauthenticated();
          return 'confirmation_required';
        }
      } else {
        state = AuthState.error('Failed to create account');
        return null;
      }
    } catch (e) {
      state = AuthState.error(e.toString());
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      state = AuthState.loading();
      await _repository.signOut();
      state = AuthState.unauthenticated();
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      if (email.isEmpty) {
        state = AuthState.error('Please enter your email address');
        return;
      }

      if (!_isValidEmail(email)) {
        state = AuthState.error('Please enter a valid email address');
        return;
      }

      state = AuthState.loading();
      await _repository.resetPassword(email: email);
      state = AuthState.unauthenticated();
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  /// Clear error
  void clearError() {
    if (state.error != null) {
      print('🧹 AUTH PROVIDER: Clearing error state');
      _isSettingErrorState = false;
      // Create new state without error
      state = AuthState(
        user: state.user,
        isLoading: false,
        error: null,
      );
    }
  }

  /// Email validation
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}

/// Auth State Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

/// Current User Provider
final currentUserProvider = Provider<supabase.User?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user;
});

/// Is Authenticated Provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isAuthenticated;
});
