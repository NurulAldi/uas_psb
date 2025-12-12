import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/auth/data/repositories/profile_repository.dart';
import 'package:rentlens/features/auth/domain/models/user_profile.dart';
import 'package:rentlens/features/auth/controllers/auth_controller.dart';

/// Provider for ProfileRepository
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

/// Provider for current user profile
/// Automatically fetches profile when user is authenticated
final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  // Watch auth state to refetch when user changes
  final authState = ref.watch(authControllerProvider);

  return authState.maybeWhen(
    data: (user) async {
      if (user == null) return null;

      final repository = ref.read(profileRepositoryProvider);
      return await repository.getCurrentUserProfile();
    },
    orElse: () => null,
  );
});

/// Provider for profile by ID
final profileByIdProvider =
    FutureProvider.family<UserProfile?, String>((ref, userId) async {
  final repository = ref.read(profileRepositoryProvider);
  return await repository.getProfileById(userId);
});

/// State notifier for managing profile updates
class ProfileUpdateController extends StateNotifier<AsyncValue<void>> {
  final ProfileRepository _repository;
  final Ref _ref;

  ProfileUpdateController(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  /// Update user profile
  Future<bool> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
  }) async {
    state = const AsyncValue.loading();

    try {
      print('👤 PROFILE UPDATE: Updating profile...');

      await _repository.updateProfile(
        fullName: fullName,
        phoneNumber: phoneNumber,
        avatarUrl: avatarUrl,
        latitude: latitude,
        longitude: longitude,
        address: address,
        city: city,
      );

      state = const AsyncValue.data(null);
      print('✅ PROFILE UPDATE: Profile updated successfully');

      // Refresh the profile provider to show updated data
      _ref.invalidate(currentUserProfileProvider);

      return true;
    } catch (e, stackTrace) {
      print('❌ PROFILE UPDATE: Error updating profile = $e');
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }
}

/// Provider for profile update controller
final profileUpdateControllerProvider =
    StateNotifierProvider<ProfileUpdateController, AsyncValue<void>>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return ProfileUpdateController(repository, ref);
});
