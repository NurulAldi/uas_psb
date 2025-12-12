import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:rentlens/core/services/location_service.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/features/auth/data/repositories/profile_repository.dart';
import 'package:rentlens/features/auth/providers/profile_provider.dart';

/// Location Setup Page
/// First-time setup or update user location for 20km radius rental feature
class LocationSetupPage extends ConsumerStatefulWidget {
  final bool isFirstTime;

  const LocationSetupPage({
    super.key,
    this.isFirstTime = false,
  });

  @override
  ConsumerState<LocationSetupPage> createState() => _LocationSetupPageState();
}

class _LocationSetupPageState extends ConsumerState<LocationSetupPage> {
  final _locationService = LocationService();
  final _profileRepository = ProfileRepository();

  bool _isLoading = false;
  bool _isServiceEnabled = false;
  Position? _currentPosition;
  String? _address;
  String? _city;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkLocationService();
  }

  Future<void> _checkLocationService() async {
    final isEnabled = await _locationService.isLocationServiceEnabled();
    setState(() => _isServiceEnabled = isEnabled);
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _currentPosition = await _locationService.getCurrentLocation();

      if (_currentPosition != null) {
        // Get address and city from coordinates
        _address = await _locationService.getAddressFromCoordinates(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
        );

        _city = await _locationService.getCityFromCoordinates(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
        );

        setState(() {});
      } else {
        setState(
            () => _errorMessage = 'Unable to get location. Please try again.');
      }
    } on LocationServiceDisabledException catch (e) {
      setState(() => _errorMessage = e.toString());
      _isServiceEnabled = false;
    } on PermissionDeniedException catch (e) {
      setState(() => _errorMessage = e.toString());
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLocation() async {
    if (_currentPosition == null || _address == null || _city == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please get your current location first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _profileRepository.updateLocation(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        address: _address!,
        city: _city!,
      );

      // Refresh profile
      ref.invalidate(currentUserProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Location saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to home
        if (widget.isFirstTime) {
          context.go('/');
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildLocationIcon() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: const Icon(
        Icons.location_on,
        size: 60,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLocationInfo() {
    if (_currentPosition == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Location Found!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.location_city,
            'City',
            _city ?? 'Unknown',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.home_outlined,
            'Address',
            _address ?? 'Unknown',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.gps_fixed,
            'Coordinates',
            '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.radar,
            'Accuracy',
            '${_currentPosition!.accuracy.toStringAsFixed(0)}m',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.green[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[900]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isFirstTime ? 'Set Your Location' : 'Update Location'),
        automaticallyImplyLeading: !widget.isFirstTime,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Center(child: _buildLocationIcon()),
              const SizedBox(height: 32),

              // Title
              Text(
                widget.isFirstTime
                    ? 'Welcome to RentLens!'
                    : 'Update Your Location',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'To provide the best rental experience, we only show '
                'products within 20km of your location. This ensures faster '
                'pickup and return times.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Why Location Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Text(
                          'Why we need this',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildBenefitItem('⚡ Faster pickups (15-30 mins)'),
                    _buildBenefitItem('💰 Lower logistics costs'),
                    _buildBenefitItem('🤝 Local community trust'),
                    _buildBenefitItem('🎯 See only relevant products'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Error message
              _buildErrorMessage(),
              if (_errorMessage != null) const SizedBox(height: 16),

              // Location info
              _buildLocationInfo(),
              if (_currentPosition != null) const SizedBox(height: 24),

              // Get Location Button
              if (_currentPosition == null)
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _getCurrentLocation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _isLoading ? 'Getting Location...' : 'Use Current Location',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

              // Save Location Button
              if (_currentPosition != null)
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveLocation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _isLoading ? 'Saving...' : 'Confirm & Continue',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

              // Open Settings Button (if service disabled)
              if (!_isServiceEnabled) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await _locationService.openLocationSettings();
                    _checkLocationService();
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Location Settings'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],

              // Skip Button (only for first time, not recommended)
              if (widget.isFirstTime) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Skip Location Setup?'),
                              content: const Text(
                                'You won\'t be able to see or rent products '
                                'until you set your location. You can do this later '
                                'from your profile settings.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    context.go('/');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                  ),
                                  child: const Text('Skip Anyway'),
                                ),
                              ],
                            ),
                          );
                        },
                  child: const Text('Skip for now'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.blue[900],
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }
}
