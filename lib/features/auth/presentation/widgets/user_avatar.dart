import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rentlens/core/theme/app_colors.dart';

/// Reusable User Avatar Widget with proper error handling
///
/// Handles:
/// - Loading states
/// - Network errors (400, 404, etc.)
/// - Invalid URLs
/// - Fallback to default icon
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;
  final IconData fallbackIcon;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.radius = 20,
    this.backgroundColor,
    this.iconColor,
    this.fallbackIcon = Icons.person_outline,
  });

  bool get _hasValidUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) return false;

    try {
      final uri = Uri.parse(avatarUrl!);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.backgroundGrey,
      child: _hasValidUrl
          ? CachedNetworkImage(
              imageUrl: avatarUrl!,
              imageBuilder: (context, imageProvider) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              placeholder: (context, url) => SizedBox(
                width: radius * 0.6,
                height: radius * 0.6,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (context, url, error) {
                // Log error for debugging
                debugPrint('❌ Avatar load failed: $error');
                debugPrint('   URL: $url');

                // Show friendly error in development
                if (error.toString().contains('400')) {
                  debugPrint(
                      '   Issue: Storage bucket may not be public or file not accessible');
                } else if (error.toString().contains('404')) {
                  debugPrint('   Issue: File not found in storage');
                }

                // Return fallback icon
                return Icon(
                  fallbackIcon,
                  size: radius * 1.1,
                  color: iconColor ?? AppColors.textTertiary,
                );
              },
            )
          : Icon(
              fallbackIcon,
              size: radius * 1.1,
              color: iconColor ?? AppColors.textTertiary,
            ),
    );
  }
}

/// Large profile avatar variant for profile pages
class LargeUserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final VoidCallback? onTap;
  final bool showEditButton;
  final bool isLoading;

  const LargeUserAvatar({
    super.key,
    this.avatarUrl,
    this.onTap,
    this.showEditButton = false,
    this.isLoading = false,
  });

  bool get _hasValidUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) return false;

    try {
      final uri = Uri.parse(avatarUrl!);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Gradient border
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: CircleAvatar(
            radius: 64,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: AppColors.backgroundGrey,
              child: _hasValidUrl
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      imageBuilder: (context, imageProvider) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) {
                        debugPrint('❌ Large avatar load failed: $error');
                        debugPrint('   URL: $url');

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person,
                              size: 60,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Load Failed',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : Icon(
                      Icons.person,
                      size: 60,
                      color: AppColors.textTertiary,
                    ),
            ),
          ),
        ),

        // Edit button
        if (showEditButton)
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              elevation: 4,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: isLoading ? null : onTap,
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLoading ? Colors.grey : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLoading ? Icons.hourglass_bottom : Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
