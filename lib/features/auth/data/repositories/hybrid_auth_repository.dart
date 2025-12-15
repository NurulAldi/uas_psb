import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rentlens/core/config/supabase_config.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Hybrid Authentication Repository
/// Supports both Supabase Auth and Custom User Management
///
/// Authentication Strategies:
/// 1. Supabase Auth (existing users) - Email/Password via auth.users
/// 2. Custom Auth (new users) - Username/Password via custom_users table
class HybridAuthRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Get current user (works for both auth types)
  User? get currentSupabaseUser => _supabase.auth.currentUser;

  /// Get auth state stream (for Supabase Auth users)
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // ============================================================
  // SUPABASE AUTH METHODS (Existing Users - No Changes)
  // ============================================================

  /// Sign in with Supabase Auth (email/password)
  /// Used for existing users created before migration
  Future<AuthResponse> signInWithSupabaseAuth({
    required String email,
    required String password,
  }) async {
    try {
      print('🔵 HYBRID AUTH: Attempting Supabase Auth sign in: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      print('✅ HYBRID AUTH: Supabase Auth sign in successful');
      print('   User ID: ${response.user?.id}');
      print('   Auth Type: supabase_auth');

      return response;
    } on AuthException catch (e) {
      print('❌ HYBRID AUTH: Supabase Auth Exception: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ HYBRID AUTH: Supabase Auth error: ${e.toString()}');
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  /// Sign up with Supabase Auth (email/password)
  /// Can still be used for new users who want email-based auth
  Future<AuthResponse> signUpWithSupabaseAuth({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    try {
      print('🔵 HYBRID AUTH: Attempting Supabase Auth sign up: $email');

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phone_number': phoneNumber,
        },
      );

      print('✅ HYBRID AUTH: Supabase Auth sign up successful');
      print('   User ID: ${response.user?.id}');
      print('   Auth Type: supabase_auth');

      return response;
    } on AuthException catch (e) {
      print('❌ HYBRID AUTH: Supabase Auth Exception: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ HYBRID AUTH: Supabase Auth error: ${e.toString()}');
      throw Exception('Failed to sign up: ${e.toString()}');
    }
  }

  // ============================================================
  // CUSTOM AUTH METHODS (New Users - Manual Management)
  // ============================================================

  /// Sign up with Custom Auth (username/password)
  /// No email validation required, no Supabase Auth constraints
  Future<Map<String, dynamic>> signUpWithCustomAuth({
    required String username,
    required String password,
    String? email, // Optional
    String? fullName,
    String? phoneNumber,
  }) async {
    try {
      print('🔵 HYBRID AUTH: Attempting Custom Auth sign up: $username');

      // Validate username format
      if (username.length < 3) {
        throw Exception('Username must be at least 3 characters');
      }
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        throw Exception(
            'Username can only contain letters, numbers, and underscores');
      }

      // Check if username already exists
      final existingUser = await _supabase
          .from('custom_users')
          .select('username')
          .eq('username', username)
          .maybeSingle();

      if (existingUser != null) {
        throw Exception('Username is already taken');
      }

      // Hash password (using SHA-256 for now, consider bcrypt for production)
      // TODO: For production, use bcrypt via a server-side function or Edge Function
      final passwordHash = _hashPassword(password);

      // Insert new custom user
      final response = await _supabase
          .from('custom_users')
          .insert({
            'username': username,
            'password_hash': passwordHash,
            'email': email,
            'full_name': fullName,
            'phone_number': phoneNumber,
            'role': 'user',
            'is_banned': false,
          })
          .select()
          .single();

      print('✅ HYBRID AUTH: Custom Auth sign up successful');
      print('   User ID: ${response['id']}');
      print('   Username: ${response['username']}');
      print('   Auth Type: custom');

      return response;
    } on PostgrestException catch (e) {
      print('❌ HYBRID AUTH: Database error during sign up: ${e.message}');
      throw Exception('Failed to create account: ${e.message}');
    } catch (e) {
      print('❌ HYBRID AUTH: Custom Auth error: ${e.toString()}');
      rethrow;
    }
  }

  /// Sign in with Custom Auth (username/password)
  Future<Map<String, dynamic>> signInWithCustomAuth({
    required String username,
    required String password,
  }) async {
    try {
      print('🔵 HYBRID AUTH: Attempting Custom Auth sign in: $username');

      // Get user by username
      final userResponse = await _supabase.rpc('get_custom_user_by_username',
          params: {'p_username': username}).maybeSingle();

      if (userResponse == null) {
        // Increment login attempts even if user doesn't exist (security)
        await _supabase
            .rpc('increment_login_attempts', params: {'p_username': username});
        throw Exception('Invalid username or password');
      }

      final user = userResponse as Map<String, dynamic>;

      // Check if account is locked
      if (user['locked_until'] != null) {
        final lockedUntil = DateTime.parse(user['locked_until']);
        if (lockedUntil.isAfter(DateTime.now())) {
          final remainingMinutes =
              lockedUntil.difference(DateTime.now()).inMinutes;
          throw Exception(
              'Account is locked. Try again in $remainingMinutes minutes');
        }
      }

      // Check if account is banned
      if (user['is_banned'] == true) {
        throw Exception(
            'Your account has been banned. Contact support for assistance');
      }

      // Verify password
      final passwordHash = _hashPassword(password);
      if (passwordHash != user['password_hash']) {
        // Increment login attempts on failed password
        await _supabase
            .rpc('increment_login_attempts', params: {'p_username': username});
        throw Exception('Invalid username or password');
      }

      // Update last login timestamp and reset login attempts
      await _supabase
          .rpc('update_custom_user_login', params: {'p_user_id': user['id']});

      // Get full user profile
      final profile = await _supabase
          .from('custom_users')
          .select()
          .eq('id', user['id'])
          .single();

      print('✅ HYBRID AUTH: Custom Auth sign in successful');
      print('   User ID: ${profile['id']}');
      print('   Username: ${profile['username']}');
      print('   Auth Type: custom');

      return profile;
    } on PostgrestException catch (e) {
      print('❌ HYBRID AUTH: Database error during sign in: ${e.message}');
      throw Exception('Failed to sign in: ${e.message}');
    } catch (e) {
      print('❌ HYBRID AUTH: Custom Auth error: ${e.toString()}');
      rethrow;
    }
  }

  /// Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final result = await _supabase
          .rpc('username_exists', params: {'p_username': username});
      return !(result as bool);
    } catch (e) {
      print('❌ Error checking username availability: $e');
      return false;
    }
  }

  // ============================================================
  // UNIFIED METHODS (Work for both auth types)
  // ============================================================

  /// Get user profile (works for both Supabase Auth and Custom Auth)
  Future<Map<String, dynamic>?> getUserProfile(
      String userId, String authType) async {
    try {
      if (authType == 'supabase_auth') {
        final profile = await _supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        return profile;
      } else {
        final profile = await _supabase
            .from('custom_users')
            .select()
            .eq('id', userId)
            .maybeSingle();
        return profile;
      }
    } catch (e) {
      print('❌ Error fetching user profile: $e');
      return null;
    }
  }

  /// Check if user is banned (works for both auth types)
  Future<bool> checkBanStatus(String userId, String authType) async {
    try {
      print(
          '🔒 HYBRID AUTH: Checking ban status for user: $userId ($authType)');

      Map<String, dynamic>? response;

      if (authType == 'supabase_auth') {
        response = await _supabase
            .from('profiles')
            .select('is_banned')
            .eq('id', userId)
            .maybeSingle();
      } else {
        response = await _supabase
            .from('custom_users')
            .select('is_banned')
            .eq('id', userId)
            .maybeSingle();
      }

      if (response == null) {
        print('⚠️ HYBRID AUTH: No profile found for user');
        throw Exception('User profile not found');
      }

      final isBanned = response['is_banned'] as bool? ?? false;
      print('🔒 HYBRID AUTH: Ban status = $isBanned');

      return isBanned;
    } catch (e) {
      print('❌ HYBRID AUTH: Error checking ban status: $e');
      rethrow;
    }
  }

  /// Sign out (works for both auth types)
  Future<void> signOut() async {
    try {
      print('🧹 HYBRID AUTH: Starting sign out...');

      // Sign out from Supabase Auth (if authenticated)
      if (_supabase.auth.currentUser != null) {
        await _supabase.auth.signOut();
      }

      // Clear custom auth session (if any)
      // TODO: Implement custom session management

      print('✅ HYBRID AUTH: Sign out completed');

      // Add small delay to ensure session is fully cleared
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      print('⚠️ HYBRID AUTH: Error during sign out: ${e.toString()}');
    }
  }

  // ============================================================
  // PASSWORD MANAGEMENT
  // ============================================================

  /// Reset password for Supabase Auth users
  Future<void> resetPasswordSupabaseAuth({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to reset password: ${e.toString()}');
    }
  }

  /// Reset password for Custom Auth users
  /// (Requires custom implementation - email/SMS verification)
  Future<void> resetPasswordCustomAuth({
    required String username,
    required String newPassword,
    required String verificationCode, // TODO: Implement verification system
  }) async {
    // TODO: Implement password reset flow for custom users
    // 1. Send verification code via email/SMS
    // 2. Verify code
    // 3. Update password
    throw UnimplementedError(
        'Password reset for custom auth not yet implemented');
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Hash password using SHA-256
  /// WARNING: For production, use bcrypt or argon2 via server-side function
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Handle Supabase Auth exceptions
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
