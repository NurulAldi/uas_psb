import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/auth/data/repositories/auth_repository.dart';
import 'package:rentlens/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Auth Controller using AsyncValue for reactive state management
class AuthController extends StateNotifier<AsyncValue<supabase.User?>> {
  final AuthRepository _repository;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthController(this._repository) : super(const AsyncValue.data(null)) {
    _checkCurrentUser();
    _listenToAuthChanges();
  }

  /// Check current user on initialization
  void _checkCurrentUser() {
    final currentUser = _repository.currentUser;
    if (currentUser != null) {
      state = AsyncValue.data(currentUser);
    }
  }

  /// Listen to auth state changes from Supabase
  void _listenToAuthChanges() {
    // CRITICAL: Store subscription to dispose later (prevent memory leak)
    _authSubscription = _repository.authStateChanges.listen(
      (event) {
        if (event.session != null) {
          print('✅ AUTH CONTROLLER: User authenticated via listener');
          // Always update to authenticated state (clears loading and error)
          state = AsyncValue.data(event.session!.user);
        } else {
          print('🔓 AUTH CONTROLLER: User signed out via listener');
          // Always clear to unauthenticated state on sign out
          // Error states are only for operation failures, not sign out
          state = const AsyncValue.data(null);
        }
      },
      onError: (error) {
        print('❌ AUTH CONTROLLER: Auth stream error: $error');
        state = AsyncValue.error(error, StackTrace.current);
      },
    );
  }

  @override
  void dispose() {
    // CRITICAL: Cancel subscription to prevent memory leak
    print('🧹 AUTH CONTROLLER: Disposing and cancelling auth subscription');
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Sign in with email and password
  /// Returns Future<void> - State is updated through AsyncValue
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    // Trim inputs for consistency
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();

    // Validate inputs
    if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
      state = AsyncValue.error(
        'Please fill in all fields',
        StackTrace.current,
      );
      return;
    }

    if (!_isValidEmail(trimmedEmail)) {
      state = AsyncValue.error(
        'Please enter a valid email address',
        StackTrace.current,
      );
      return;
    }

    // Set loading state
    state = const AsyncValue.loading();
    print('🔄 AUTH CONTROLLER: Signing in...');

    try {
      // Attempt sign in with trimmed values
      final response = await _repository.signInWithEmail(
        email: trimmedEmail,
        password: trimmedPassword,
      );

      // Check response
      if (response.user != null && response.session != null) {
        print('✅ AUTH CONTROLLER: Sign in successful');
        print('   🎯 Listener will update state automatically');
        // Listener will update state - but add small delay to ensure it fires
        // If listener doesn't fire within 100ms, we set state manually as fallback
        await Future.delayed(const Duration(milliseconds: 100));

        // Fallback: If still loading, set authenticated state manually
        if (state.isLoading) {
          print('⚠️ AUTH CONTROLLER: Listener delayed, setting state manually');
          state = AsyncValue.data(response.user);
        }
      } else {
        print('❌ AUTH CONTROLLER: No user or session in response');
        state = AsyncValue.error(
          'Failed to sign in',
          StackTrace.current,
        );
      }
    } catch (e, stackTrace) {
      print('❌ AUTH CONTROLLER: Sign in failed: $e');

      // Clear any existing session first
      try {
        await _repository.signOut();
        print('🧹 AUTH CONTROLLER: Session cleared after error');
      } catch (signOutError) {
        print('⚠️ AUTH CONTROLLER: Error during cleanup: $signOutError');
      }

      // Set error state - THIS prevents navigation
      state = AsyncValue.error(e.toString(), stackTrace);
    }
  }

  /// Sign up with email and password
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    // Trim all inputs for consistency
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();
    final trimmedFullName = fullName.trim();
    final trimmedPhone = phoneNumber?.trim();

    // Validate inputs
    if (trimmedEmail.isEmpty ||
        trimmedPassword.isEmpty ||
        trimmedFullName.isEmpty) {
      state = AsyncValue.error(
        'Please fill in all required fields',
        StackTrace.current,
      );
      return null;
    }

    if (!_isValidEmail(trimmedEmail)) {
      state = AsyncValue.error(
        'Please enter a valid email address',
        StackTrace.current,
      );
      return null;
    }

    if (trimmedPassword.length < 6) {
      state = AsyncValue.error(
        'Password must be at least 6 characters',
        StackTrace.current,
      );
      return null;
    }

    state = const AsyncValue.loading();

    try {
      final response = await _repository.signUpWithEmail(
        email: trimmedEmail,
        password: trimmedPassword,
        fullName: trimmedFullName,
        phoneNumber: trimmedPhone,
      );

      if (response.user != null) {
        final session = response.session;
        if (session != null) {
          // Auto-confirmed, user can login immediately
          print('✅ AUTH CONTROLLER: Sign up successful with auto-confirm');
          print('   🎯 Listener will update state automatically');
          // Wait for listener to update state
          await Future.delayed(const Duration(milliseconds: 100));

          // Fallback: If still loading, set authenticated state manually
          if (state.isLoading) {
            print(
                '⚠️ AUTH CONTROLLER: Listener delayed, setting state manually');
            state = AsyncValue.data(response.user);
          }
          return 'success';
        } else {
          // Email confirmation required
          print('⚠️ AUTH CONTROLLER: Email confirmation required');
          state = const AsyncValue.data(null);
          return 'confirmation_required';
        }
      } else {
        state = AsyncValue.error(
          'Failed to create account',
          StackTrace.current,
        );
        return null;
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e.toString(), stackTrace);
      return null;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = const AsyncValue.loading();

    try {
      await _repository.signOut();
      print('✅ AUTH CONTROLLER: Sign out successful');
      print('   🎯 Listener will update state automatically');
      // Don't set state here - let listener handle it
      // Wait briefly for listener to fire
      await Future.delayed(const Duration(milliseconds: 100));

      // Fallback: If still loading, set unauthenticated manually
      if (state.isLoading) {
        print('⚠️ AUTH CONTROLLER: Listener delayed, setting state manually');
        state = const AsyncValue.data(null);
      }
    } catch (e, stackTrace) {
      print('❌ AUTH CONTROLLER: Sign out failed: $e');
      state = AsyncValue.error(e.toString(), stackTrace);
    }
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    // Trim email for consistency
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      state = AsyncValue.error(
        'Please enter your email address',
        StackTrace.current,
      );
      return;
    }

    if (!_isValidEmail(trimmedEmail)) {
      state = AsyncValue.error(
        'Please enter a valid email address',
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();

    try {
      await _repository.resetPassword(email: trimmedEmail);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e.toString(), stackTrace);
    }
  }

  /// Clear error state
  void clearError() {
    if (state.hasError) {
      print('🧹 AUTH CONTROLLER: Clearing error state');
      // Simply clear to unauthenticated state
      // If user is actually authenticated, listener will update
      state = const AsyncValue.data(null);
    }
  }

  /// Email validation with improved regex
  bool _isValidEmail(String email) {
    // More robust email validation:
    // - No consecutive dots
    // - No leading/trailing dots in local part
    // - Allows + for gmail aliases
    // - TLD can be 2+ characters (supports .community, .technology, etc)
    return RegExp(
            r'^[a-zA-Z0-9][a-zA-Z0-9._%+-]*[a-zA-Z0-9]@[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }
}

/// Auth Controller Provider
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<supabase.User?>>((ref) {
  // Use authRepositoryProvider from auth_provider.dart (single source of truth)
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

/// Convenience providers for easier access
final currentUserProvider = Provider<supabase.User?>((ref) {
  final authState = ref.watch(authControllerProvider);
  // CRITICAL FIX: Use maybeWhen to safely extract value
  return authState.maybeWhen(
    data: (user) => user,
    orElse: () => null,
  );
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  // CRITICAL FIX: Use maybeWhen to safely check authentication
  return authState.maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});

final isLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.isLoading;
});
