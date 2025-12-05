import 'package:rentlens/core/config/supabase_config.dart';
import 'package:rentlens/features/auth/domain/models/user_profile.dart';

/// Profile Repository
/// Handles fetching and updating user profile data from Supabase
class ProfileRepository {
  final _supabase = SupabaseConfig.client;

  /// Get profile for current user
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        print('⚠️ PROFILE REPOSITORY: No authenticated user');
        return null;
      }

      print('👤 PROFILE REPOSITORY: Fetching profile for user: $userId');

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        print('⚠️ PROFILE REPOSITORY: No profile found for user');
        return null;
      }

      print('✅ PROFILE REPOSITORY: Profile found');
      print('   Full Name: ${response['full_name']}');
      print('   Email: ${response['email']}');

      return UserProfile.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ PROFILE REPOSITORY: Error fetching profile = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get profile by user ID
  Future<UserProfile?> getProfileById(String userId) async {
    try {
      print('👤 PROFILE REPOSITORY: Fetching profile for user: $userId');

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        print('⚠️ PROFILE REPOSITORY: No profile found');
        return null;
      }

      return UserProfile.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ PROFILE REPOSITORY: Error fetching profile = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Update current user profile
  Future<void> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        throw Exception('No authenticated user');
      }

      print('👤 PROFILE REPOSITORY: Updating profile...');

      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      if (updates.isEmpty) {
        print('⚠️ PROFILE REPOSITORY: No updates to apply');
        return;
      }

      await _supabase.from('profiles').update(updates).eq('id', userId);

      print('✅ PROFILE REPOSITORY: Profile updated successfully');
    } catch (e, stackTrace) {
      print('❌ PROFILE REPOSITORY: Error updating profile = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
