import 'package:flutter/material.dart';
import 'package:rentlens/core/theme/app_colors.dart';

/// Distance badge for product cards
/// Shows distance from user with visual indicator
class ProductDistanceBadge extends StatelessWidget {
  final double distanceKm;
  final int? travelTimeMinutes;
  final bool compact;

  const ProductDistanceBadge({
    Key? key,
    required this.distanceKm,
    this.travelTimeMinutes,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final distanceText = _formatDistance(distanceKm);
    final timeText = travelTimeMinutes != null
        ? _formatTravelTime(travelTimeMinutes!)
        : null;

    if (compact) {
      return _buildCompactBadge(distanceText);
    }

    return _buildFullBadge(distanceText, timeText);
  }

  Widget _buildFullBadge(String distanceText, String? timeText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _getDistanceColor(distanceKm).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getDistanceColor(distanceKm).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            size: 14,
            color: _getDistanceColor(distanceKm),
          ),
          const SizedBox(width: 4),
          Text(
            distanceText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _getDistanceColor(distanceKm),
            ),
          ),
          if (timeText != null) ...[
            const SizedBox(width: 6),
            Text(
              '•',
              style: TextStyle(
                fontSize: 12,
                color: _getDistanceColor(distanceKm).withOpacity(0.5),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.directions_car,
              size: 12,
              color: _getDistanceColor(distanceKm).withOpacity(0.7),
            ),
            const SizedBox(width: 4),
            Text(
              timeText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _getDistanceColor(distanceKm).withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactBadge(String distanceText) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.location_on,
          size: 12,
          color: _getDistanceColor(distanceKm),
        ),
        const SizedBox(width: 2),
        Text(
          distanceText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _getDistanceColor(distanceKm),
          ),
        ),
      ],
    );
  }

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    } else if (km < 10) {
      return '${km.toStringAsFixed(1)} km';
    } else {
      return '${km.round()} km';
    }
  }

  String _formatTravelTime(int minutes) {
    if (minutes < 1) {
      return '<1 min';
    } else if (minutes < 60) {
      return '$minutes min';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return '$hours hr';
      }
      return '$hours hr $mins min';
    }
  }

  Color _getDistanceColor(double km) {
    if (km < 5) {
      return const Color(0xFF10B981); // Green - very close
    } else if (km < 15) {
      return AppColors.primary; // Blue - moderate
    } else if (km < 30) {
      return const Color(0xFFF59E0B); // Orange - far
    } else {
      return const Color(0xFFEF4444); // Red - very far
    }
  }
}
