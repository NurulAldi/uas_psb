import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/auth/data/repositories/auth_repository.dart';
import 'package:rentlens/features/auth/domain/models/auth_state.dart';
import 'package:rentlens/features/auth/domain/models/user_profile.dart';

/// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Auth State Notifier - Manual Authentication
/// NO Supabase Auth - uses custom users table with username/password
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState.initial()) {
    _init();
  }

  /// Initialize auth state from SharedPreferences
  Future<void> _init() async {
    try {
      final userProfile = await _repository.getCurrentUserProfile();
      if (userProfile != null) {
        print('✅ AUTH PROVIDER: Found existing user: ${userProfile.username}');
        state = AuthState.authenticatedWithProfile(userProfile);
      } else {
        print('ℹ️ AUTH PROVIDER: No existing user');
        state = AuthState.unauthenticated();
      }
    } catch (e) {
      print('❌ AUTH PROVIDER: Error initializing: $e');
      state = AuthState.unauthenticated();
    }
  }

  /// Sign in with username and password
  Future<void> signInWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      print('🔵 AUTH PROVIDER: signInWithUsername called');

      // Validate inputs
      if (username.isEmpty || password.isEmpty) {
        print('❌ AUTH PROVIDER: Empty fields');
        state = AuthState.error('Harap isi semua field');
        return;
      }

      if (username.length < 3) {
        print('❌ AUTH PROVIDER: Username too short');
        state = AuthState.error('Username minimal 3 karakter');
        return;
      }

      print('🔄 AUTH PROVIDER: Setting loading state...');
      state = AuthState.loading();

      print('🔄 AUTH PROVIDER: Calling repository signInWithUsername...');
      final user = await _repository.signInWithUsername(
        username: username.trim().toLowerCase(),
        password: password,
      );

      print('📦 AUTH PROVIDER: Login successful - User: ${user.username}');

      // Check if user is banned
      if (user.isBanned) {
        print('🚫 AUTH PROVIDER: User is banned!');
        await _repository.signOut();
        state = AuthState.error('Akun Anda telah diblokir');
        return;
      }

      state = AuthState.authenticatedWithProfile(user);
    } catch (e) {
      print('❌ AUTH PROVIDER: Exception caught = ${e.toString()}');
      state = AuthState.error(e.toString());
    }
  }

  /// Sign up with username and password
  Future<String?> signUpWithUsername({
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phoneNumber,
  }) async {
    try {
      // Validate inputs
      if (username.isEmpty || password.isEmpty || fullName.isEmpty) {
        state = AuthState.error('Harap isi semua field yang wajib');
        return null;
      }

      if (username.length < 3) {
        state = AuthState.error('Username minimal 3 karakter');
        return null;
      }

      if (password.length < 6) {
        state = AuthState.error('Password minimal 6 karakter');
        return null;
      }

      state = AuthState.loading();

      final user = await _repository.signUpWithUsername(
        username: username.trim().toLowerCase(),
        password: password,
        fullName: fullName.trim(),
        email: email?.trim(),
        phoneNumber: phoneNumber?.trim(),
      );

      print('✅ AUTH PROVIDER: Registration successful for: ${user.username}');
      state = AuthState.authenticatedWithProfile(user);
      return 'success';
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

  /// Clear error
  void clearError() {
    if (state.error != null) {
      print('🧹 AUTH PROVIDER: Clearing error state');
      state = AuthState.unauthenticated();
    }
  }

  /// Refresh profile
  Future<void> refreshProfile() async {
    try {
      final userProfile = await _repository.getCurrentUserProfile();
      if (userProfile != null) {
        state = AuthState.authenticatedWithProfile(userProfile);
      }
    } catch (e) {
      print('❌ AUTH PROVIDER: Error refreshing profile: $e');
    }
  }
}

/// Auth State Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

/// Current User Provider (returns UserProfile)
final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.userProfile;
});

/// Alias for backwards compatibility
final currentUserProvider = currentUserProfileProvider;

/// Is Authenticated Provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isAuthenticated;
});
