import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service to handle all location-related operations
/// Including GPS location, distance calculation, and geocoding
class LocationService {
  /// Maximum rental radius in kilometers (20km)
  static const double MAX_RENTAL_RADIUS_KM = 20.0;

  /// Minimum accuracy required for location in meters
  static const double MIN_LOCATION_ACCURACY = 100.0;

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission from user
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current GPS location with error handling
  /// Returns null if permission denied or service disabled
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationServiceDisabledException();
      }

      // Check permission
      LocationPermission permission = await checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          throw PermissionDeniedException('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw PermissionDeniedException(
          'Location permission permanently denied. Please enable in settings.',
        );
      }

      // Get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Validate accuracy
      if (position.accuracy > MIN_LOCATION_ACCURACY) {
        // Try again with best accuracy
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 10),
        );
      }

      return position;
    } on LocationServiceDisabledException {
      rethrow;
    } on PermissionDeniedException {
      rethrow;
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  /// Calculate distance between two GPS coordinates in kilometers
  /// Uses Haversine formula (same as backend SQL function)
  double calculateDistance({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) {
    // Geolocator returns distance in meters, convert to km
    final distanceInMeters = Geolocator.distanceBetween(
      startLat,
      startLon,
      endLat,
      endLon,
    );

    return distanceInMeters / 1000; // Convert to kilometers
  }

  /// Check if distance is within rental radius (20km)
  bool isWithinRentalRadius(double distanceKm) {
    return distanceKm <= MAX_RENTAL_RADIUS_KM;
  }

  /// Format distance for display
  /// Examples: "1.5 km", "12 km", "500 m"
  String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      // Less than 1km, show in meters
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    } else if (distanceKm < 10) {
      // Less than 10km, show 1 decimal
      return '${distanceKm.toStringAsFixed(1)} km';
    } else {
      // 10km or more, show whole number
      return '${distanceKm.round()} km';
    }
  }

  /// Get estimated travel time based on distance
  /// Assumes average city speed of 30 km/h
  String getEstimatedTravelTime(double distanceKm) {
    const avgSpeedKmh = 30.0; // Average city speed
    final hours = distanceKm / avgSpeedKmh;
    final minutes = (hours * 60).round();

    if (minutes < 5) {
      return '< 5 mins';
    } else if (minutes < 60) {
      return '$minutes mins';
    } else {
      final hrs = (minutes / 60).floor();
      final mins = minutes % 60;
      return mins > 0 ? '$hrs hr $mins mins' : '$hrs hr';
    }
  }

  /// Get address from GPS coordinates (Reverse Geocoding)
  Future<String> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Validate coordinates before geocoding
      if (!isValidCoordinate(latitude: latitude, longitude: longitude)) {
        print(
            '❌ Invalid coordinates for geocoding: lat=$latitude, lon=$longitude');
        return 'Invalid coordinates';
      }

      // Check for NaN or infinite values
      if (latitude.isNaN ||
          longitude.isNaN ||
          latitude.isInfinite ||
          longitude.isInfinite) {
        print('❌ NaN/Infinite coordinates: lat=$latitude, lon=$longitude');
        return 'Invalid coordinates';
      }

      print(
          '📍 Attempting reverse geocoding for: lat=$latitude, lon=$longitude');

      List<Placemark> placemarks;
      try {
        placemarks = await placemarkFromCoordinates(
          latitude,
          longitude,
        );
      } catch (geocodingError, st) {
        print('⚠️ Platform geocoding failed: $geocodingError');
        print('Stack trace: $st');
        print('🔄 Falling back to HTTP geocoding...');

        // Fallback to HTTP-based geocoding
        return await _fallbackReverseGeocode(latitude, longitude);
      }

      if (placemarks.isEmpty) {
        return 'Unknown location';
      }

      Placemark place = placemarks.first;

      // Build readable address
      final parts = <String>[];

      // Safely access properties without forcing non-null
      final street = place.street;
      final subLocality = place.subLocality;
      final locality = place.locality;

      if (street != null && street.isNotEmpty) {
        parts.add(street);
      }
      if (subLocality != null && subLocality.isNotEmpty) {
        parts.add(subLocality);
      }
      if (locality != null && locality.isNotEmpty) {
        parts.add(locality);
      }

      return parts.isEmpty ? 'Unknown location' : parts.join(', ');
    } catch (e, st) {
      print('❌ Error reverse geocoding: $e');
      print('Stack trace: $st');
      return 'Location unavailable';
    }
  }

  /// Get city name from GPS coordinates
  /// Returns city name like "Padang", "Kab. Pesisir Selatan", or province name
  Future<String> getCityFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Validate coordinates before geocoding
      if (!isValidCoordinate(latitude: latitude, longitude: longitude)) {
        print(
            '❌ Invalid coordinates for city geocoding: lat=$latitude, lon=$longitude');
        return 'Unknown';
      }

      // Check for NaN or infinite values
      if (latitude.isNaN ||
          longitude.isNaN ||
          latitude.isInfinite ||
          longitude.isInfinite) {
        print(
            '❌ NaN/Infinite coordinates for city: lat=$latitude, lon=$longitude');
        return 'Unknown';
      }

      print('🏙️ Attempting city geocoding for: lat=$latitude, lon=$longitude');

      List<Placemark> placemarks;
      try {
        placemarks = await placemarkFromCoordinates(
          latitude,
          longitude,
        );
      } catch (geocodingError, st) {
        print('⚠️ Platform city geocoding failed: $geocodingError');
        print('Stack trace: $st');
        print('🔄 Falling back to HTTP city geocoding...');

        // Fallback to HTTP-based geocoding for city
        return await _fallbackCityGeocode(latitude, longitude);
      }

      if (placemarks.isEmpty) {
        return 'Unknown';
      }

      Placemark place = placemarks.first;

      print('📍 Geocoding result:');
      print('   Locality: ${place.locality}');
      print('   SubLocality: ${place.subLocality}');
      print('   SubAdminArea: ${place.subAdministrativeArea}');
      print('   AdminArea: ${place.administrativeArea}');

      // Priority: locality (city) > subAdministrativeArea (kabupaten) > administrativeArea (province)
      String? cityName;

      // 1. Try locality (city name like "Padang", "Jakarta")
      final locality = place.locality;
      if (locality != null &&
          locality.isNotEmpty &&
          locality.toLowerCase() != 'unknown') {
        cityName = locality;
      }
      // 2. Try subAdministrativeArea (district/kabupaten)
      else {
        final subAdminArea = place.subAdministrativeArea;
        if (subAdminArea != null && subAdminArea.isNotEmpty) {
          cityName = subAdminArea;
          // Shorten "Kabupaten" to "Kab."
          if (cityName.toLowerCase().startsWith('kabupaten ')) {
            cityName = 'Kab. ${cityName.substring(10)}';
          }
        }
        // 3. Fallback to province
        else {
          final adminArea = place.administrativeArea;
          if (adminArea != null && adminArea.isNotEmpty) {
            cityName = adminArea;
          }
        }
      }

      if (cityName == null || cityName.isEmpty) {
        return 'Unknown';
      }

      print('✅ City name: $cityName');
      return cityName;
    } catch (e, st) {
      print('❌ Error getting city: $e');
      print('Stack trace: $st');
      return 'Unknown';
    }
  }

  /// Get coordinates from address (Forward Geocoding)
  Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        return null;
      }

      Location location = locations.first;

      return Position(
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    } catch (e) {
      print('❌ Error geocoding address: $e');
      return null;
    }
  }

  /// Validate coordinates are within valid range
  bool isValidCoordinate({
    required double latitude,
    required double longitude,
  }) {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  /// Check if two locations are approximately the same
  /// (within 100 meters)
  bool areLocationsClose({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
    double thresholdMeters = 100,
  }) {
    final distanceKm = calculateDistance(
      startLat: lat1,
      startLon: lon1,
      endLat: lat2,
      endLon: lon2,
    );

    return (distanceKm * 1000) <= thresholdMeters;
  }

  /// Fallback HTTP-based reverse geocoding using Nominatim (OpenStreetMap)
  Future<String> _fallbackReverseGeocode(
      double latitude, double longitude) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude&addressdetails=1&zoom=18');

      print('🌐 HTTP geocoding request: $uri');

      final response = await http.get(uri, headers: {
        'User-Agent': 'RentLens/1.0 (contact@rentlens.app)',
      });

      if (response.statusCode != 200) {
        print('❌ HTTP geocoding failed with status: ${response.statusCode}');
        return 'Location unavailable';
      }

      final data = jsonDecode(response.body);
      final displayName = data['display_name'] as String?;

      if (displayName != null && displayName.isNotEmpty) {
        print('✅ HTTP geocoding success: $displayName');
        return displayName;
      } else {
        print('❌ HTTP geocoding returned empty result');
        return 'Location unavailable';
      }
    } catch (httpError, st) {
      print('❌ HTTP geocoding fallback failed: $httpError');
      print('Stack trace: $st');
      return 'Location unavailable';
    }
  }

  /// Fallback HTTP-based city geocoding using Nominatim (OpenStreetMap)
  Future<String> _fallbackCityGeocode(double latitude, double longitude) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude&addressdetails=1&zoom=10');

      print('🌐 HTTP city geocoding request: $uri');

      final response = await http.get(uri, headers: {
        'User-Agent': 'RentLens/1.0 (contact@rentlens.app)',
      });

      if (response.statusCode != 200) {
        print(
            '❌ HTTP city geocoding failed with status: ${response.statusCode}');
        return 'Unknown';
      }

      final data = jsonDecode(response.body);
      final address = data['address'] as Map<String, dynamic>?;

      if (address != null) {
        // Try to extract city name from various possible fields
        String? city = address['city'] ??
            address['town'] ??
            address['village'] ??
            address['county'] ??
            address['state'] ??
            address['province'];

        if (city != null && city.isNotEmpty) {
          // Handle Indonesian administrative divisions
          if (city.toLowerCase().startsWith('kabupaten ')) {
            city = 'Kab. ${city.substring(10)}';
          }
          print('✅ HTTP city geocoding success: $city');
          return city;
        }
      }

      print('❌ HTTP city geocoding returned no city data');
      return 'Unknown';
    } catch (httpError, st) {
      print('❌ HTTP city geocoding fallback failed: $httpError');
      print('Stack trace: $st');
      return 'Unknown';
    }
  }

  /// Open app settings (for permission management)
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}

/// Exception when location service is disabled
class LocationServiceDisabledException implements Exception {
  final String message;

  LocationServiceDisabledException([
    this.message = 'Location services are disabled. Please enable GPS.',
  ]);

  @override
  String toString() => message;
}

/// Exception when location permission is denied
class PermissionDeniedException implements Exception {
  final String message;

  PermissionDeniedException([
    this.message = 'Location permission denied.',
  ]);

  @override
  String toString() => message;
}
