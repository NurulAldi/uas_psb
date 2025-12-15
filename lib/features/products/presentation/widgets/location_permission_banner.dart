import 'package:flutter/material.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';

/// Location permission request banner
/// Shown when location permission is not granted
class LocationPermissionBanner extends StatelessWidget {
  final VoidCallback onRequestPermission;
  final VoidCallback? onOpenSettings;
  final bool isPermanentlyDenied;

  const LocationPermissionBanner({
    Key? key,
    required this.onRequestPermission,
    this.onOpenSettings,
    this.isPermanentlyDenied = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Location Access Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            isPermanentlyDenied
                ? 'Location permission is permanently denied. Please enable it in app settings to discover nearby rental cameras.'
                : 'We need your location to show you rental cameras available within 20km of your area.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Action buttons
          if (isPermanentlyDenied)
            // Open settings button
            ElevatedButton.icon(
              onPressed: onOpenSettings ?? () => openAppSettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.settings, size: 20),
              label: const Text(
                'Open Settings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            // Request permission button
            ElevatedButton.icon(
              onPressed: onRequestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.location_on, size: 20),
              label: const Text(
                'Allow Location Access',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Learn more button
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showLocationInfoDialog(context),
            child: Text(
              'Why do we need this?',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text('About Location Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RentLens uses your location to:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildInfoItem(
              icon: Icons.near_me,
              text: 'Show cameras available near you (within 20km)',
            ),
            _buildInfoItem(
              icon: Icons.local_shipping,
              text: 'Calculate pickup/return distance and time',
            ),
            _buildInfoItem(
              icon: Icons.people,
              text: 'Connect you with nearby owners for faster transactions',
            ),
            _buildInfoItem(
              icon: Icons.lock_outline,
              text: 'Your exact location is never shared with others',
            ),
            const SizedBox(height: 12),
            Text(
              'You can change this permission anytime in your device settings.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
