import 'package:flutter/material.dart';
import 'package:rentlens/core/constants/app_strings.dart';
import 'package:rentlens/core/theme/app_colors.dart';

/// Empty state when no nearby products are found
class NoNearbyProductsWidget extends StatelessWidget {
  final double currentRadius;
  final VoidCallback? onIncreaseRadius;
  final VoidCallback? onRefresh;

  const NoNearbyProductsWidget({
    Key? key,
    required this.currentRadius,
    this.onIncreaseRadius,
    this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final nextRadius = _getNextRadiusOption(currentRadius);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              AppStrings.noNearbyProducts,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              'Tidak ada kamera rental tersedia dalam $currentRadius km dari lokasi Anda.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Suggestions
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.tryText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSuggestionItem(
                  icon: Icons.zoom_out_map,
                  text: AppStrings.increasingSearchRadius,
                ),
                _buildSuggestionItem(
                  icon: Icons.refresh,
                  text: AppStrings.refreshingNewListings,
                ),
                _buildSuggestionItem(
                  icon: Icons.schedule,
                  text: AppStrings.checkingBackLater,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Action buttons
            if (nextRadius != null && onIncreaseRadius != null)
              ElevatedButton.icon(
                onPressed: onIncreaseRadius,
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
                icon: const Icon(Icons.zoom_out_map, size: 20),
                label: Text(
                  '${AppStrings.increaseRadiusTo} $nextRadius km',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            if (onRefresh != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRefresh,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text(
                  AppStrings.refresh,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.primary.withOpacity(0.7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double? _getNextRadiusOption(double current) {
    const options = [10.0, 20.0, 30.0, 40.0, 50.0];
    final index = options.indexOf(current);
    if (index >= 0 && index < options.length - 1) {
      return options[index + 1];
    }
    return null;
  }
}
