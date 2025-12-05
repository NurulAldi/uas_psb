import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/auth/data/repositories/auth_repository.dart';
import 'package:rentlens/features/auth/providers/auth_repository_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Auth Controller using AsyncValue for reactive state management
/// CRITICAL: State updates ONLY from auth stream listener
class AuthController extends StateNotifier<AsyncValue<supabase.User?>> {
  final AuthRepository _repository;
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthController(this._repository) : super(const AsyncValue.loading()) {
    _initializeAuth();
  }

  /// Expose auth state changes stream for router refresh
  Stream<supabase.AuthState> get authStateChanges =>
      _repository.authStateChanges;

  /// Initialize: Check current user + start listening
  void _initializeAuth() {
    print('🔵 AUTH CONTROLLER: Initializing...');

    final currentUser = _repository.currentUser;
    if (currentUser != null) {
      print('✅ AUTH CONTROLLER: Found existing user: ${currentUser.email}');
      state = AsyncValue.data(currentUser);
    } else {
      print('ℹ️ AUTH CONTROLLER: No existing user');
      state = const AsyncValue.data(null);
    }

    _listenToAuthChanges();
  }

  /// CRITICAL: Only source of state updates from Supabase
  void _listenToAuthChanges() {
    print('👂 AUTH CONTROLLER: Starting to listen to auth changes');

    _authSubscription = _repository.authStateChanges.listen(
      (event) {
        if (event.session != null) {
          print('✅ AUTH LISTENER: User authenticated');
          print('   User: ${event.session!.user.email}');
          // Always update to authenticated state
          state = AsyncValue.data(event.session!.user);
        } else {
          print('🔓 AUTH LISTENER: User signed out');
          // Always clear to unauthenticated state
          state = const AsyncValue.data(null);
        }
      },
      onError: (error) {
        print('❌ AUTH LISTENER: Stream error: $error');
        state = AsyncValue.error(error, StackTrace.current);
      },
    );
  }

  @override
  void dispose() {
    print('🧹 AUTH CONTROLLER: Disposing and cancelling subscription');
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Sign in with email and password
  /// NO manual state update - listener handles it
  Future<void> signIn(String email, String password) async {
    print('\n🔵 AUTH CONTROLLER: signIn called');

    // Trim inputs
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();

    // Basic validation
    if (trimmedEmail.isEmpty || trimmedPassword.isEmpty) {
      state = AsyncValue.error(
        'Please fill in all fields',
        StackTrace.current,
      );
      return;
    }

    if (!trimmedEmail.contains('@')) {
      state = AsyncValue.error(
        'Please enter a valid email',
        StackTrace.current,
      );
      return;
    }

    // Set loading state
    state = const AsyncValue.loading();
    print('🔄 AUTH CONTROLLER: Loading...');

    try {
      // Call repository
      final response = await _repository.signInWithEmail(
        email: trimmedEmail,
        password: trimmedPassword,
      );

      print('✅ AUTH CONTROLLER: Repository call successful');

      // CRITICAL: Check if user is banned
      if (response.user != null) {
        final userId = response.user!.id;
        print('🔒 AUTH CONTROLLER: Checking ban status...');

        final isBanned = await _repository.checkBanStatus(userId);

        if (isBanned) {
          print('🚫 AUTH CONTROLLER: User is banned! Signing out...');

          // Immediately sign out the banned user
          await _repository.signOut();

          // Throw special error for banned users
          throw 'ACCOUNT_BANNED';
        }

        print('✅ AUTH CONTROLLER: User is not banned, proceeding...');
      }

      print('   Listener will update state automatically');

      // NO manual state update here!
      // Listener will handle it when auth state changes
    } catch (e, stackTrace) {
      print('❌ AUTH CONTROLLER: Sign in failed: $e');
      state = AsyncValue.error(e.toString(), stackTrace);
    }
  }

  /// Sign up with email and password
  /// NO manual state update - listener handles it
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    print('\n🔵 AUTH CONTROLLER: signUp called');

    // Trim inputs
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();
    final trimmedFullName = fullName.trim();
    final trimmedPhone = phoneNumber?.trim();

    // Basic validation
    if (trimmedEmail.isEmpty ||
        trimmedPassword.isEmpty ||
        trimmedFullName.isEmpty) {
      state = AsyncValue.error(
        'Please fill in all required fields',
        StackTrace.current,
      );
      return;
    }

    if (!trimmedEmail.contains('@')) {
      state = AsyncValue.error(
        'Please enter a valid email',
        StackTrace.current,
      );
      return;
    }

    if (trimmedPassword.length < 6) {
      state = AsyncValue.error(
        'Password must be at least 6 characters',
        StackTrace.current,
      );
      return;
    }

    // Set loading state
    state = const AsyncValue.loading();
    print('🔄 AUTH CONTROLLER: Loading...');

    try {
      // Call repository
      final response = await _repository.signUpWithEmail(
        email: trimmedEmail,
        password: trimmedPassword,
        fullName: trimmedFullName,
        phoneNumber: trimmedPhone,
      );

      print('✅ AUTH CONTROLLER: Repository call successful');

      // Check if email confirmation is required
      if (response.user != null && response.session == null) {
        print('⚠️ AUTH CONTROLLER: Email confirmation required');
        // Set special error state for email confirmation
        state = AsyncValue.error(
          'EMAIL_CONFIRMATION_REQUIRED',
          StackTrace.current,
        );
        return;
      }

      print('   Listener will update state automatically');
      // NO manual state update here!
      // Listener will handle it when auth state changes
    } catch (e, stackTrace) {
      print('❌ AUTH CONTROLLER: Sign up failed: $e');
      state = AsyncValue.error(e.toString(), stackTrace);
    }
  }

  /// Sign out
  /// NO manual state update - listener handles it
  Future<void> signOut() async {
    print('\n🔵 AUTH CONTROLLER: signOut called');

    state = const AsyncValue.loading();
    print('🔄 AUTH CONTROLLER: Loading...');

    try {
      // Call repository
      await _repository.signOut();

      print('✅ AUTH CONTROLLER: Repository call successful');
      print('   Listener will update state automatically');

      // NO manual state update here!
      // Listener will handle it when auth state changes
    } catch (e, stackTrace) {
      print('❌ AUTH CONTROLLER: Sign out failed: $e');
      state = AsyncValue.error(e.toString(), stackTrace);
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    print('\n🔵 AUTH CONTROLLER: resetPassword called');

    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      state = AsyncValue.error(
        'Please enter your email',
        StackTrace.current,
      );
      return;
    }

    if (!trimmedEmail.contains('@')) {
      state = AsyncValue.error(
        'Please enter a valid email',
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();

    try {
      await _repository.resetPassword(email: trimmedEmail);
      print('✅ AUTH CONTROLLER: Password reset email sent');
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      print('❌ AUTH CONTROLLER: Reset password failed: $e');
      state = AsyncValue.error(e.toString(), stackTrace);
    }
  }

  /// Clear error state
  void clearError() {
    if (state.hasError) {
      print('🧹 AUTH CONTROLLER: Clearing error state');
      state = const AsyncValue.data(null);
    }
  }
}

/// Auth Controller Provider
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<supabase.User?>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

/// Convenience providers for easier access
final currentUserProvider = Provider<supabase.User?>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.maybeWhen(
    data: (user) => user,
    orElse: () => null,
  );
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});

final isLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authControllerProvider);
  return authState.isLoading;
});
