import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/products/data/repositories/product_repository.dart';
import 'package:rentlens/features/products/domain/models/product_with_distance.dart';
import 'package:rentlens/features/products/providers/product_provider.dart';
import 'package:rentlens/core/services/location_service.dart';

/// State untuk nearby products filter
class NearbyProductsState {
  final List<ProductWithDistance> products;
  final double radiusKm;
  final bool isLoading;
  final String? error;
  final double? userLat;
  final double? userLon;

  const NearbyProductsState({
    this.products = const [],
    this.radiusKm = 20.0,
    this.isLoading = false,
    this.error,
    this.userLat,
    this.userLon,
  });

  NearbyProductsState copyWith({
    List<ProductWithDistance>? products,
    double? radiusKm,
    bool? isLoading,
    String? error,
    double? userLat,
    double? userLon,
  }) {
    return NearbyProductsState(
      products: products ?? this.products,
      radiusKm: radiusKm ?? this.radiusKm,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      userLat: userLat ?? this.userLat,
      userLon: userLon ?? this.userLon,
    );
  }
}

/// Controller untuk nearby products dengan adjustable radius
class NearbyProductsController extends StateNotifier<NearbyProductsState> {
  final ProductRepository _repository;
  final LocationService _locationService;

  NearbyProductsController(this._repository, this._locationService)
      : super(const NearbyProductsState());

  /// Fetch nearby products dengan radius yang bisa diatur
  Future<void> fetchNearbyProducts({double? customRadiusKm}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get user location
      final location = await _locationService.getCurrentLocation();
      if (location == null) {
        throw Exception(
            'Unable to get location. Please enable location services.');
      }

      final radiusKm = customRadiusKm ?? state.radiusKm;

      print('📍 NEARBY PRODUCTS: Fetching products within $radiusKm km');
      print('   User location: (${location.latitude}, ${location.longitude})');

      // Fetch nearby products
      final products = await _repository.getNearbyProducts(
        userLat: location.latitude,
        userLon: location.longitude,
        radiusKm: radiusKm,
      );

      state = state.copyWith(
        products: products,
        radiusKm: radiusKm,
        isLoading: false,
        userLat: location.latitude,
        userLon: location.longitude,
      );

      print('✅ NEARBY PRODUCTS: Found ${products.length} products');
    } catch (e) {
      print('❌ NEARBY PRODUCTS: Error = $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Update radius dan refresh products
  Future<void> updateRadius(double newRadiusKm) async {
    if (newRadiusKm == state.radiusKm) return;
    await fetchNearbyProducts(customRadiusKm: newRadiusKm);
  }

  /// Refresh products dengan radius saat ini
  Future<void> refresh() async {
    await fetchNearbyProducts();
  }
}

/// Provider untuk nearby products controller
final nearbyProductsControllerProvider =
    StateNotifierProvider<NearbyProductsController, NearbyProductsState>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  final locationService = LocationService();
  return NearbyProductsController(repository, locationService);
});
