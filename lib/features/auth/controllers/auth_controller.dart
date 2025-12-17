import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/auth/data/repositories/auth_repository.dart';
import 'package:rentlens/features/auth/providers/auth_repository_provider.dart';
import 'package:rentlens/features/auth/domain/models/auth_state.dart';
import 'package:rentlens/features/auth/domain/models/user_profile.dart';

/// Auth Controller using consolidated AuthState
/// MANUAL AUTH - NO Supabase Auth, uses custom users table
/// Single source of truth for authentication state
class AuthController extends StateNotifier<AsyncValue<AuthState>> {
  final AuthRepository _repository;

  AuthController(this._repository)
      : super(const AsyncValue.data(AuthState.initializing())) {
    // Auto-initialize on creation
    initialize();
  }

  /// Initialize: Check if user is logged in from SharedPreferences
  /// This is called on app startup
  Future<void> initialize() async {
    print('🔵 AUTH CONTROLLER: Initializing authentication...');

    // Set initializing state
    state = const AsyncValue.data(AuthState.initializing());

    try {
      final userProfile = await _repository.getCurrentUserProfile();

      if (userProfile != null) {
        print(
            '✅ AUTH CONTROLLER: Found existing session for: ${userProfile.username}');
        state = AsyncValue.data(AuthState.authenticated(userProfile));
      } else {
        print('ℹ️ AUTH CONTROLLER: No existing session found');
        state = const AsyncValue.data(AuthState.unauthenticated());
      }
    } catch (e, stackTrace) {
      print('❌ AUTH CONTROLLER: Error during initialization: $e');
      state = AsyncValue.data(
          AuthState.unauthenticated('Failed to initialize: $e'));
    }
  }

  /// Sign in with username and password
  /// Uses manual authentication (NO Supabase Auth) - validates against users table
  Future<void> signIn(String username, String password) async {
    print('\n🔵 AUTH CONTROLLER: signIn called for username: $username');

    // Trim inputs
    final trimmedUsername = username.trim().toLowerCase();
    final trimmedPassword = password.trim();

    // Basic validation
    if (trimmedUsername.isEmpty || trimmedPassword.isEmpty) {
      state = AsyncValue.data(
        const AuthState.unauthenticated('Harap isi semua field'),
      );
      return;
    }

    if (trimmedUsername.length < 3) {
      state = AsyncValue.data(
        const AuthState.unauthenticated('Username minimal 3 karakter'),
      );
      return;
    }

    // IMPORTANT: Use AsyncValue.loading instead of changing AuthState
    // This shows loading indicator WITHOUT triggering router redirect
    state = const AsyncValue.loading();
    print('🔄 AUTH CONTROLLER: Authenticating...');

    try {
      // Call repository with manual auth (validates against users table)
      final user = await _repository.signInWithUsername(
        username: trimmedUsername,
        password: trimmedPassword,
      );

      print('✅ AUTH CONTROLLER: Login successful for: ${user.username}');

      // Check if user is banned
      if (user.isBanned) {
        print('🚫 AUTH CONTROLLER: User is banned!');
        await _repository.signOut();
        state = AsyncValue.data(
          const AuthState.unauthenticated('ACCOUNT_BANNED'),
        );
        return;
      }

      // Set authenticated state with complete user profile
      state = AsyncValue.data(AuthState.authenticated(user));
    } catch (e, stackTrace) {
      print('❌ AUTH CONTROLLER: Sign in failed: $e');
      // Set error state that shows inline error WITHOUT redirect
      // Stay unauthenticated but with error message
      state = AsyncValue.data(AuthState.unauthenticated(e.toString()));
    }
  }

  /// Sign up with username and password
  /// Uses manual authentication (NO Supabase Auth) - creates user in users table
  Future<void> signUp({
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phoneNumber,
  }) async {
    print('\n🔵 AUTH CONTROLLER: signUp called for username: $username');

    // Trim inputs
    final trimmedUsername = username.trim().toLowerCase();
    final trimmedPassword = password.trim();
    final trimmedFullName = fullName.trim();
    final trimmedEmail = email?.trim();
    final trimmedPhone = phoneNumber?.trim();

    // Basic validation
    if (trimmedUsername.isEmpty ||
        trimmedPassword.isEmpty ||
        trimmedFullName.isEmpty) {
      state = AsyncValue.data(
        const AuthState.unauthenticated('Harap isi semua field yang wajib'),
      );
      return;
    }

    if (trimmedUsername.length < 3) {
      state = AsyncValue.data(
        const AuthState.unauthenticated('Username minimal 3 karakter'),
      );
      return;
    }

    if (trimmedPassword.length < 6) {
      state = AsyncValue.data(
        const AuthState.unauthenticated('Password minimal 6 karakter'),
      );
      return;
    }

    // Set initializing state (shows loading in UI)
    state = const AsyncValue.data(AuthState.initializing());
    print('🔄 AUTH CONTROLLER: Registering user...');

    try {
      // Call repository with manual auth (creates user in users table)
      final user = await _repository.signUpWithUsername(
        username: trimmedUsername,
        password: trimmedPassword,
        fullName: trimmedFullName,
        email: trimmedEmail,
        phoneNumber: trimmedPhone,
      );

      print('✅ AUTH CONTROLLER: Registration successful for: ${user.username}');

      // Set authenticated state with complete user profile
      state = AsyncValue.data(AuthState.authenticated(user));
    } catch (e, stackTrace) {
      print('❌ AUTH CONTROLLER: Sign up failed: $e');
      state = AsyncValue.data(AuthState.unauthenticated(e.toString()));
    }
  }

  /// Sign out - clear local session
  Future<void> signOut() async {
    print('\n🔵 AUTH CONTROLLER: signOut called');

    // Set initializing state briefly
    state = const AsyncValue.data(AuthState.initializing());
    print('🔄 AUTH CONTROLLER: Clearing session...');

    try {
      await _repository.signOut();
      print('✅ AUTH CONTROLLER: Sign out successful');

      // Set unauthenticated state
      state = const AsyncValue.data(AuthState.unauthenticated());
    } catch (e, stackTrace) {
      print('❌ AUTH CONTROLLER: Sign out failed: $e');
      // Even if signout fails, clear the state
      state = const AsyncValue.data(AuthState.unauthenticated());
    }
  }

  /// Clear error state
  void clearError() {
    final currentState = state.value;
    if (currentState?.hasError == true) {
      print('🧹 AUTH CONTROLLER: Clearing error state');
      state = const AsyncValue.data(AuthState.unauthenticated());
    }
  }

  /// Refresh current user profile from database
  Future<void> refreshProfile() async {
    try {
      print('🔄 AUTH CONTROLLER: Refreshing user profile...');
      final userProfile = await _repository.getCurrentUserProfile();

      if (userProfile != null) {
        state = AsyncValue.data(AuthState.authenticated(userProfile));
        print(
            '✅ AUTH CONTROLLER: Profile refreshed for: ${userProfile.username}');
      } else {
        state = const AsyncValue.data(AuthState.unauthenticated());
        print('⚠️ AUTH CONTROLLER: No user found during refresh');
      }
    } catch (e) {
      print('❌ AUTH CONTROLLER: Error refreshing profile: $e');
      // Don't change state on refresh error, keep current state
    }
  }
}

/// Auth Controller Provider
/// Single source of truth for authentication state
final authStateProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthState>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

/// Legacy provider name for backwards compatibility
final authControllerProvider = authStateProvider;

/// Convenience providers for easier access
final currentUserProvider = Provider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.isAuthenticated ?? false;
});

final isInitializingAuthProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.isInitializing ?? true;
});

/// Backwards compatibility provider for currentUserProfileProvider
/// This replaces the old FutureProvider pattern
final currentUserProfileProvider = Provider<AsyncValue<UserProfile?>>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (state) {
      if (state.isInitializing) {
        return const AsyncValue.loading();
      } else if (state.isAuthenticated) {
        return AsyncValue.data(state.user);
      } else {
        return const AsyncValue.data(null);
      }
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
