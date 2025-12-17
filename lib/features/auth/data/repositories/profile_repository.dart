import 'package:rentlens/core/config/supabase_config.dart';
import 'package:rentlens/features/auth/domain/models/user_profile.dart';

/// Profile Repository
/// Handles fetching and updating user profile data from Supabase
class ProfileRepository {
  final _supabase = SupabaseConfig.client;

  /// Get profile for current user
  Future<UserProfile?> getCurrentUserProfile() async {
    try {
      final userId = await SupabaseConfig.currentUserId;
      if (userId == null) {
        print('⚠️ PROFILE REPOSITORY: No authenticated user');
        return null;
      }

      print('👤 PROFILE REPOSITORY: Fetching profile for user: $userId');

      final response =
          await _supabase.from('users').select().eq('id', userId).maybeSingle();

      if (response == null) {
        print('⚠️ PROFILE REPOSITORY: No profile found for user');
        return null;
      }

      print('✅ PROFILE REPOSITORY: Profile found for user: $userId');
      print('   Profile ID in response: ${response['id']}');
      print('   Full Name: ${response['full_name']}');
      print('   Email: ${response['email']}');
      print(
          '   Has Location: ${response['latitude'] != null && response['longitude'] != null}');
      if (response['latitude'] != null) {
        print(
            '   Location: (${response['latitude']}, ${response['longitude']}) - ${response['city']}');
      }

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

      final response =
          await _supabase.from('users').select().eq('id', userId).maybeSingle();

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
    double? latitude,
    double? longitude,
    String? address,
    String? city,
  }) async {
    try {
      final userId = await SupabaseConfig.currentUserId;
      if (userId == null) {
        throw Exception('No authenticated user');
      }

      print('👤 PROFILE REPOSITORY: Updating profile for user: $userId');

      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (latitude != null) updates['latitude'] = latitude;
      if (longitude != null) updates['longitude'] = longitude;
      if (address != null) updates['address'] = address;
      if (city != null) updates['city'] = city;

      if (updates.isEmpty) {
        print('⚠️ PROFILE REPOSITORY: No updates to apply');
        return;
      }

      if (latitude != null && longitude != null) {
        print(
            '📍 Updating location for user $userId: ($latitude, $longitude) - $city');
      }

      final result = await _supabase
          .from('users')
          .update(updates)
          .eq('id', userId)
          .select();
      print(
          '✅ PROFILE REPOSITORY: Update result for user $userId: ${result.length} rows affected');

      if (result.isNotEmpty) {
        print('✅ Updated profile ID: ${result.first['id']}');
      }

      print('✅ PROFILE REPOSITORY: Profile updated successfully');
    } catch (e, stackTrace) {
      print('❌ PROFILE REPOSITORY: Error updating profile = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Update user location (for 20km radius rental feature)
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    required String address,
    required String city,
  }) async {
    try {
      final userId = await SupabaseConfig.currentUserId;
      if (userId == null) {
        throw Exception('No authenticated user');
      }

      print('📍 PROFILE REPOSITORY: Updating location...');
      print('   Coordinates: ($latitude, $longitude)');
      print('   City: $city');

      await _supabase.from('users').update({
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'city': city,
        // location_updated_at will be auto-updated by trigger
      }).eq('id', userId);

      print('✅ PROFILE REPOSITORY: Location updated successfully');
    } catch (e, stackTrace) {
      print('❌ PROFILE REPOSITORY: Error updating location = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if user has set their location
  Future<bool> hasUserSetLocation() async {
    try {
      final profile = await getCurrentUserProfile();
      return profile?.hasLocation ?? false;
    } catch (e) {
      print('❌ PROFILE REPOSITORY: Error checking location = $e');
      return false;
    }
  }
}
