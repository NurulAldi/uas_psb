import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rentlens/core/constants/app_strings.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/features/auth/providers/profile_provider.dart';
import 'package:rentlens/features/auth/domain/models/user_profile.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  Future<void> _launchMaps(double latitude, double longitude) async {
    // Try Google Maps app first (using geo: URI scheme)
    final geoUri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');

    try {
      // Try to launch with geo: scheme (opens native Maps app)
      final launched =
          await launchUrl(geoUri, mode: LaunchMode.externalApplication);

      if (!launched) {
        // Fallback to browser with Google Maps web
        final webUrl = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        );
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Last fallback: try web URL
      try {
        final webUrl = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        );
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } catch (e) {
        print('❌ Could not launch maps: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileByIdProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.userProfile),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off,
                    size: 64,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  const Text(AppStrings.userNotFoundMessage),
                ],
              ),
            );
          }
          return _buildProfileContent(context, profile);
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Error loading profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, UserProfile profile) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header dengan avatar
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white,
                  child: profile.avatarUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: profile.avatarUrl!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey,
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile
                      .displayName, // Fallback ke username jika fullName kosong
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                if (profile.city != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_city,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        profile.city!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFFB3B3B3),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Profile info
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location section with map
                if (profile.latitude != null && profile.longitude != null) ...[
                  const Text(
                    'Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Static map image (using Google Static Maps API)
                        InkWell(
                          onTap: () => _launchMaps(
                            profile.latitude!,
                            profile.longitude!,
                          ),
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.backgroundGrey,
                            ),
                            child: Stack(
                              children: [
                                // OpenStreetMap Static Image (FREE, no API key needed)
                                Positioned.fill(
                                  child: Image.network(
                                    // Using OpenStreetMap static image service
                                    'https://staticmap.openstreetmap.de/staticmap.php?'
                                    'center=${profile.latitude},${profile.longitude}&'
                                    'zoom=14&'
                                    'size=600x400&'
                                    'markers=${profile.latitude},${profile.longitude},red-pushpin',
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Loading map...',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback to placeholder if image fails to load
                                      return Stack(
                                        children: [
                                          Center(
                                            child: Icon(
                                              Icons.map,
                                              size: 64,
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                          Center(
                                            child: Icon(
                                              Icons.location_on,
                                              size: 48,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                // Tap to open hint
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.open_in_new,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Open in Maps',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Location info
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      profile.city != null &&
                                              profile.city!.isNotEmpty
                                          ? profile.city!
                                          : profile.address != null &&
                                                  profile.address!.isNotEmpty
                                              ? profile.address!
                                              : 'Location',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.gps_fixed,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${profile.latitude!.toStringAsFixed(6)}, ${profile.longitude!.toStringAsFixed(6)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Contact info
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (profile.phoneNumber != null)
                  ListTile(
                    leading: Icon(Icons.phone, color: AppColors.primary),
                    title: Text(profile.phoneNumber!),
                    contentPadding: EdgeInsets.zero,
                  ),
                if (profile.email != null)
                  ListTile(
                    leading: Icon(Icons.email, color: AppColors.primary),
                    title: Text(profile.email!),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
