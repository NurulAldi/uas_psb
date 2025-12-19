import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rentlens/core/constants/app_strings.dart';
import 'package:rentlens/core/services/location_service.dart';
import 'package:rentlens/features/products/data/repositories/product_repository.dart';
import 'package:rentlens/features/auth/providers/auth_provider.dart' as auth;
import 'package:rentlens/features/products/domain/models/product.dart';
import 'package:rentlens/features/products/domain/models/product_with_distance.dart';
import 'package:rentlens/features/products/providers/product_provider.dart';

/// Provider for LocationService
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Location-aware product state
/// Manages products with location context as the default behavior
class LocationAwareProductState {
  final List<ProductWithDistance> products;
  final Position? userLocation;
  final double radiusKm;
  final bool isLoading;
  final String? error;
  final LocationPermissionStatus permissionStatus;
  final String searchQuery;
  final ProductCategory? selectedCategory;
  final bool isRequestingPermission;

  const LocationAwareProductState({
    this.products = const [],
    this.userLocation,
    this.radiusKm = 20.0,
    this.isLoading = false,
    this.error,
    this.permissionStatus = LocationPermissionStatus.unknown,
    this.searchQuery = '',
    this.selectedCategory,
    this.isRequestingPermission = false,
  });

  // Computed properties
  bool get hasLocation => userLocation != null;
  bool get hasProducts => products.isNotEmpty;
  int get productCount => products.length;
  bool get hasPermission =>
      permissionStatus == LocationPermissionStatus.granted;
  bool get permissionDenied =>
      permissionStatus == LocationPermissionStatus.denied ||
      permissionStatus == LocationPermissionStatus.deniedPermanently;
  bool get canRequestPermission =>
      permissionStatus == LocationPermissionStatus.denied;

  String get statusMessage {
    if (error != null) return error!;
    if (isLoading) return 'Loading nearby products...';
    if (!hasPermission) return 'Location permission required';
    if (!hasLocation) return 'Getting your location...';
    if (!hasProducts) return 'No products found within $radiusKm km';
    return '$productCount products found within $radiusKm km';
  }

  LocationAwareProductState copyWith({
    List<ProductWithDistance>? products,
    Position? userLocation,
    double? radiusKm,
    bool? isLoading,
    String? error,
    LocationPermissionStatus? permissionStatus,
    String? searchQuery,
    ProductCategory? selectedCategory,
    bool clearCategory = false,
    bool? isRequestingPermission,
  }) {
    return LocationAwareProductState(
      products: products ?? this.products,
      userLocation: userLocation ?? this.userLocation,
      radiusKm: radiusKm ?? this.radiusKm,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      permissionStatus: permissionStatus ?? this.permissionStatus,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      isRequestingPermission:
          isRequestingPermission ?? this.isRequestingPermission,
    );
  }
}

enum LocationPermissionStatus {
  unknown,
  granted,
  denied,
  deniedPermanently,
}

/// Location-aware product controller
/// Makes location-based product discovery the default behavior
class LocationAwareProductController
    extends StateNotifier<LocationAwareProductState> {
  final ProductRepository _productRepository;
  final LocationService _locationService;

  LocationAwareProductController(
    this._productRepository,
    this._locationService,
  ) : super(const LocationAwareProductState()) {
    // Auto-initialize on creation
    _initialize();
  }

  /// Initialize: Check permission and load products if available
  Future<void> _initialize() async {
    print('🌍 LOCATION-AWARE CONTROLLER: Initializing...');
    await checkLocationPermission();

    if (state.hasPermission) {
      await fetchNearbyProducts();
    }
  }

  /// Check current location permission status
  Future<void> checkLocationPermission() async {
    try {
      print('🌍 LOCATION-AWARE CONTROLLER: Checking location permission...');

      final permission = await _locationService.checkPermission();
      final status = _mapPermissionStatus(permission);

      state = state.copyWith(permissionStatus: status);

      print('🌍 LOCATION-AWARE CONTROLLER: Permission status = $status');
    } catch (e) {
      print('❌ LOCATION-AWARE CONTROLLER: Error checking permission: $e');
      state = state.copyWith(
        error: AppStrings.failedToCheckLocationPermission,
      );
    }
  }

  /// Request location permission from user
  Future<bool> requestLocationPermission() async {
    try {
      print('🌍 LOCATION-AWARE CONTROLLER: Requesting location permission...');
      state = state.copyWith(isRequestingPermission: true);

      final permission = await _locationService.requestPermission();
      final status = _mapPermissionStatus(permission);

      state = state.copyWith(
        permissionStatus: status,
        isRequestingPermission: false,
      );

      print('🌍 LOCATION-AWARE CONTROLLER: Permission result = $status');

      // Auto-fetch if granted
      if (status == LocationPermissionStatus.granted) {
        await fetchNearbyProducts();
        return true;
      }

      return false;
    } catch (e) {
      print('❌ LOCATION-AWARE CONTROLLER: Error requesting permission: $e');
      state = state.copyWith(
        error: AppStrings.failedToRequestLocationPermission,
        isRequestingPermission: false,
      );
      return false;
    }
  }

  /// Fetch nearby products (primary method)
  Future<void> fetchNearbyProducts({bool forceRefresh = false}) async {
    try {
      print('🌍 LOCATION-AWARE CONTROLLER: Fetching nearby products...');
      print('   Radius: ${state.radiusKm} km');
      print('   Search: "${state.searchQuery}"');
      print('   Category: ${state.selectedCategory}');

      state = state.copyWith(isLoading: true, error: null);

      // Get current location
      Position? position = state.userLocation;
      if (position == null || forceRefresh) {
        position = await _locationService.getCurrentLocation();
        if (position == null) {
          throw Exception(AppStrings.couldNotGetLocation);
        }
      }

      state = state.copyWith(userLocation: position);

      print(
          '🌍 LOCATION-AWARE CONTROLLER: Location = (${position.latitude}, ${position.longitude})');

      // Fetch nearby products from repository
      final products = await _productRepository.getNearbyProducts(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: state.radiusKm,
        searchText: state.searchQuery.isEmpty ? null : state.searchQuery,
        category: state.selectedCategory,
      );

      print(
          '✅ LOCATION-AWARE CONTROLLER: Fetched ${products.length} nearby products');

      state = state.copyWith(
        products: products,
        isLoading: false,
      );
    } catch (e, stackTrace) {
      print('❌ LOCATION-AWARE CONTROLLER: Error fetching nearby products: $e');
      print('Stack trace: $stackTrace');

      state = state.copyWith(
        isLoading: false,
        error: '${AppStrings.failedToLoadNearbyProducts}: ${e.toString()}',
      );
    }
  }

  /// Update search query and re-fetch
  Future<void> updateSearch(String query) async {
    print('🌍 LOCATION-AWARE CONTROLLER: Updating search = "$query"');

    state = state.copyWith(searchQuery: query);

    if (state.hasLocation) {
      await fetchNearbyProducts();
    }
  }

  /// Update category filter and re-fetch
  Future<void> updateCategory(ProductCategory? category) async {
    print('🌍 LOCATION-AWARE CONTROLLER: Updating category = $category');

    state = state.copyWith(
      selectedCategory: category,
      clearCategory: category == null,
    );

    if (state.hasLocation) {
      await fetchNearbyProducts();
    }
  }

  /// Clear category filter
  Future<void> clearCategory() async {
    await updateCategory(null);
  }

  /// Update radius and re-fetch
  Future<void> updateRadius(double newRadius) async {
    print('🌍 LOCATION-AWARE CONTROLLER: Updating radius = $newRadius km');

    state = state.copyWith(radiusKm: newRadius);

    if (state.hasLocation) {
      await fetchNearbyProducts();
    }
  }

  /// Refresh products (pull-to-refresh)
  Future<void> refresh() async {
    print('🌍 LOCATION-AWARE CONTROLLER: Refreshing products...');
    await fetchNearbyProducts(forceRefresh: true);
  }

  /// Retry after error
  Future<void> retry() async {
    print('🌍 LOCATION-AWARE CONTROLLER: Retrying...');

    if (!state.hasPermission) {
      await requestLocationPermission();
    } else {
      await fetchNearbyProducts(forceRefresh: true);
    }
  }

  /// Map Geolocator permission to our enum
  LocationPermissionStatus _mapPermissionStatus(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedPermanently;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.unknown;
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider for location-aware products
final locationAwareProductControllerProvider = StateNotifierProvider.autoDispose<
    LocationAwareProductController, LocationAwareProductState>((ref) {
  // Watch current user so controller re-initializes on auth change
  ref.watch(auth.currentUserProvider);

  final productRepository = ref.watch(productRepositoryProvider);
  final locationService = ref.watch(locationServiceProvider);

  return LocationAwareProductController(
    productRepository,
    locationService,
  );
});

/// Convenience providers for specific state slices
final nearbyProductsProvider = Provider<List<ProductWithDistance>>((ref) {
  return ref.watch(locationAwareProductControllerProvider).products;
});

final userLocationProvider = Provider<Position?>((ref) {
  return ref.watch(locationAwareProductControllerProvider).userLocation;
});

final locationPermissionStatusProvider =
    Provider<LocationPermissionStatus>((ref) {
  return ref.watch(locationAwareProductControllerProvider).permissionStatus;
});

final productSearchRadiusProvider = Provider<double>((ref) {
  return ref.watch(locationAwareProductControllerProvider).radiusKm;
});
