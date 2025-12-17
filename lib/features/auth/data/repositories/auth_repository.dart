import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentlens/core/config/supabase_config.dart';
import 'package:rentlens/core/utils/password_helper.dart';
import 'package:rentlens/features/auth/domain/models/user_profile.dart';

/// Manual Authentication Repository
/// NO Supabase Auth - uses custom users table with username/password
/// Session management via SharedPreferences
class AuthRepository {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Session keys for SharedPreferences
  static const String _keyUserId = 'user_id';
  static const String _keyUsername = 'username';
  static const String _keyFullName = 'full_name';
  static const String _keyRole = 'user_role';

  /// Get current logged-in user ID from local storage
  Future<String?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  /// Check if user is currently logged in
  Future<bool> isLoggedIn() async {
    final userId = await getCurrentUserId();
    return userId != null;
  }

  /// Get current user profile from database
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final userId = await getCurrentUserId();
      if (userId == null) return null;

      final response =
          await _supabase.from('users').select().eq('id', userId).maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      print('❌ Error fetching current user profile: $e');
      return null;
    }
  }

  /// Sign in with username and password
  /// Uses PostgreSQL function: login_user(p_username, p_password)
  /// ⚠️ PLAINTEXT PASSWORD - FOR DEMO/ACADEMIC USE ONLY!
  Future<UserProfile> signInWithUsername({
    required String username,
    required String password,
  }) async {
    try {
      print('🔵 REPOSITORY: Attempting to sign in user: $username');
      print('🔍 DEBUG: Raw username: |$username| (length: ${username.length})');
      print('🔍 DEBUG: Raw password: |$password| (length: ${password.length})');

      final cleanUsername = username.trim();
      final cleanPassword = password.trim();

      print(
          '🔍 DEBUG: Clean username: |$cleanUsername| (length: ${cleanUsername.length})');
      print(
          '🔍 DEBUG: Clean password: |$cleanPassword| (length: ${cleanPassword.length})');

      // NO HASHING - Send plaintext password (DEMO ONLY!)
      // Call PostgreSQL login_user function
      final response = await _supabase.rpc('login_user', params: {
        'p_username': cleanUsername,
        'p_password': cleanPassword,
      });

      print('📦 REPOSITORY: Login response: $response');

      // Check response structure
      if (response == null) {
        throw Exception('Login gagal: Tidak ada respon dari server');
      }

      // Parse response
      final success = response['success'] as bool? ?? false;
      final error = response['error'] as String?;
      final userData = response['user'] as Map<String, dynamic>?;

      if (!success || userData == null) {
        throw Exception(error ?? 'Username atau password salah');
      }

      // Parse user data
      final user = UserProfile.fromJson(userData);

      // Check if user is banned
      if (user.isBanned) {
        throw Exception('Akun Anda telah diblokir');
      }

      // Save session to SharedPreferences
      await _saveSession(user);

      print('✅ REPOSITORY: Login successful for user: ${user.username}');
      return user;
    } on PostgrestException catch (e) {
      print('❌ REPOSITORY: Database error during login: ${e.message}');
      throw Exception('Error database: ${e.message}');
    } catch (e) {
      print('❌ REPOSITORY: Error during login: $e');
      rethrow;
    }
  }

  /// Sign up with username, password, and full name
  /// Uses PostgreSQL function: register_user(p_username, p_password, p_full_name, p_email, p_phone_number)
  /// ⚠️ PLAINTEXT PASSWORD - FOR DEMO/ACADEMIC USE ONLY!
  Future<UserProfile> signUpWithUsername({
    required String username,
    required String password,
    required String fullName,
    String? email,
    String? phoneNumber,
  }) async {
    try {
      print('🔵 REPOSITORY: Attempting to register user: $username');

      // NO HASHING - Send plaintext password (DEMO ONLY!)
      // Call PostgreSQL register_user function
      final response = await _supabase.rpc('register_user', params: {
        'p_username':
            username.trim(), // Don't lowercase - usernames are case-sensitive
        'p_password': password, // Send plaintext password
        'p_full_name': fullName.trim(),
        'p_email': email?.trim(),
        'p_phone_number': phoneNumber?.trim(),
      });

      print('📦 REPOSITORY: Registration response: $response');

      // Check response structure
      if (response == null) {
        throw Exception('Registrasi gagal: Tidak ada respon dari server');
      }

      // Parse response
      final success = response['success'] as bool? ?? false;
      final error = response['error'] as String?;
      final userData = response['user'] as Map<String, dynamic>?;

      if (!success || userData == null) {
        throw Exception(error ?? 'Registrasi gagal');
      }

      // Parse user data
      final user = UserProfile.fromJson(userData);

      // Save session to SharedPreferences
      await _saveSession(user);

      print('✅ REPOSITORY: Registration successful for user: ${user.username}');
      return user;
    } on PostgrestException catch (e) {
      print('❌ REPOSITORY: Database error during registration: ${e.message}');

      // Handle unique constraint violations
      if (e.message.contains('users_username_key')) {
        throw Exception('Username sudah digunakan');
      }
      if (e.message.contains('users_email_key')) {
        throw Exception('Email sudah digunakan');
      }

      throw Exception('Error database: ${e.message}');
    } catch (e) {
      print('❌ REPOSITORY: Error during registration: $e');
      rethrow;
    }
  }

  /// Sign out - clear local session
  Future<void> signOut() async {
    try {
      print('🧹 REPOSITORY: Starting sign out...');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUsername);
      await prefs.remove(_keyFullName);
      await prefs.remove(_keyRole);

      print('✅ REPOSITORY: Sign out completed');
    } catch (e) {
      print('⚠️ REPOSITORY: Error during sign out: $e');
    }
  }

  /// Check if user is banned
  /// Returns true if banned, false if not
  Future<bool> checkBanStatus(String userId) async {
    try {
      print('🔒 REPOSITORY: Checking ban status for user: $userId');

      final response = await _supabase
          .from('users')
          .select('is_banned')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        print('⚠️ REPOSITORY: No user found');
        throw Exception('User tidak ditemukan');
      }

      final isBanned = response['is_banned'] as bool? ?? false;
      print('🔒 REPOSITORY: Ban status = $isBanned');

      return isBanned;
    } catch (e) {
      print('❌ REPOSITORY: Error checking ban status: $e');
      rethrow;
    }
  }

  /// Update user profile (fullName, email, phoneNumber)
  Future<UserProfile> updateProfile({
    required String userId,
    String? fullName,
    String? email,
    String? phoneNumber,
  }) async {
    try {
      print('🔧 REPOSITORY: Updating profile for user: $userId');

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updates['full_name'] = fullName.trim();
      if (email != null) updates['email'] = email.trim();
      if (phoneNumber != null) updates['phone_number'] = phoneNumber.trim();

      final response = await _supabase
          .from('users')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      final updatedUser = UserProfile.fromJson(response);

      // Update session data
      await _saveSession(updatedUser);

      print('✅ REPOSITORY: Profile updated successfully');
      return updatedUser;
    } on PostgrestException catch (e) {
      print('❌ REPOSITORY: Database error updating profile: ${e.message}');

      // Handle unique constraint violations
      if (e.message.contains('users_email_key')) {
        throw Exception('Email sudah digunakan oleh user lain');
      }

      throw Exception('Error database: ${e.message}');
    } catch (e) {
      print('❌ REPOSITORY: Error updating profile: $e');
      rethrow;
    }
  }

  /// Update user password
  Future<void> updatePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      print('🔧 REPOSITORY: Updating password for user: $userId');

      // Verify old password first
      final user = await _supabase
          .from('users')
          .select('password_hash')
          .eq('id', userId)
          .single();

      final storedHash = user['password_hash'] as String;
      final oldPasswordHash = PasswordHelper.hashPassword(oldPassword);

      if (storedHash != oldPasswordHash) {
        throw Exception('Password lama tidak sesuai');
      }

      // Update to new password
      final newPasswordHash = PasswordHelper.hashPassword(newPassword);

      await _supabase.from('users').update({
        'password_hash': newPasswordHash,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      print('✅ REPOSITORY: Password updated successfully');
    } on PostgrestException catch (e) {
      print('❌ REPOSITORY: Database error updating password: ${e.message}');
      throw Exception('Error database: ${e.message}');
    } catch (e) {
      print('❌ REPOSITORY: Error updating password: $e');
      rethrow;
    }
  }

  /// Save user session to SharedPreferences
  Future<void> _saveSession(UserProfile user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, user.id);
    await prefs.setString(_keyUsername, user.username);
    if (user.fullName != null) {
      await prefs.setString(_keyFullName, user.fullName!);
    }
    await prefs.setString(_keyRole, user.role);

    print('💾 Session saved for user: ${user.username}');
  }
}
