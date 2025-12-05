import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rentlens/core/config/supabase_config.dart';

/// Authentication Repository
/// Handles all authentication operations with Supabase
class AuthRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Get auth state stream
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      print('🔵 REPOSITORY: Attempting to sign in user: $email');
      // Controller already trims inputs, repository receives clean data
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      print('✅ REPOSITORY: Sign in response received');
      print('   User ID: ${response.user?.id}');
      print('   Email: ${response.user?.email}');
      print('   Session: ${response.session != null ? "Active" : "Null"}');

      return response;
    } on AuthException catch (e) {
      print('❌ REPOSITORY: Auth Exception during sign in: ${e.message}');
      print('   Status Code: ${e.statusCode}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ REPOSITORY: Error during sign in: ${e.toString()}');
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    try {
      print('🔵 Attempting to sign up user: $email');
      // Controller already trims inputs, repository receives clean data
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phone_number': phoneNumber,
        },
      );

      print('✅ Sign up response received');
      print('   User ID: ${response.user?.id}');
      print('   Email: ${response.user?.email}');
      print(
          '   Session: ${response.session != null ? "Active" : "Null (Email confirmation required)"}');

      return response;
    } on AuthException catch (e) {
      print('❌ Auth Exception during sign up: ${e.message}');
      print('   Status Code: ${e.statusCode}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Error during sign up: ${e.toString()}');
      throw Exception('Failed to sign up: ${e.toString()}');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      print('🧹 REPOSITORY: Starting sign out...');
      await _supabase.auth.signOut();
      print('✅ REPOSITORY: Sign out completed');

      // Add small delay to ensure session is fully cleared
      await Future.delayed(const Duration(milliseconds: 50));
    } on AuthException catch (e) {
      // Silently catch signOut errors during cleanup
      print('⚠️ REPOSITORY: Error during sign out: ${e.message}');
    } catch (e) {
      // Silently catch signOut errors during cleanup
      print('⚠️ REPOSITORY: Error during sign out: ${e.toString()}');
    }
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      // Controller handles trimming, repository receives clean data
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to reset password: ${e.toString()}');
    }
  }

  /// Check if user is banned
  /// Returns true if banned, false if not
  /// Throws exception if profile not found or error occurs
  Future<bool> checkBanStatus(String userId) async {
    try {
      print('🔒 REPOSITORY: Checking ban status for user: $userId');

      final response = await _supabase
          .from('profiles')
          .select('is_banned')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        print('⚠️ REPOSITORY: No profile found for user');
        throw Exception('User profile not found');
      }

      final isBanned = response['is_banned'] as bool? ?? false;
      print('🔒 REPOSITORY: Ban status = $isBanned');

      return isBanned;
    } catch (e) {
      print('❌ REPOSITORY: Error checking ban status: $e');
      rethrow;
    }
  }

  /// Update user profile
  Future<UserResponse> updateProfile({
    String? fullName,
    String? phoneNumber,
  }) async {
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            if (fullName != null) 'full_name': fullName,
            if (phoneNumber != null) 'phone_number': phoneNumber,
          },
        ),
      );
      return response;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  /// Handle auth exceptions with user-friendly messages
  String _handleAuthException(AuthException e) {
    switch (e.statusCode) {
      case '400':
        if (e.message.contains('Invalid login credentials')) {
          return 'Invalid email or password';
        }
        if (e.message.contains('User already registered')) {
          return 'Email is already registered';
        }
        if (e.message.contains('is invalid') ||
            e.message.contains('Email address')) {
          return 'Please use a valid email address (e.g., yourname@gmail.com)';
        }
        return e.message;
      case '422':
        if (e.message.contains('Password should be at least')) {
          return 'Password must be at least 6 characters';
        }
        return 'Invalid input: ${e.message}';
      case '429':
        return 'Too many requests. Please try again later';
      default:
        return e.message;
    }
  }
}
