import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/products/data/repositories/product_repository.dart';
import 'package:rentlens/features/products/domain/models/product.dart';

/// Product Repository Provider
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

/// All Products Provider
/// Fetches all products from Supabase
final allProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProducts();
});

/// Available Products Provider
/// Fetches only available products
final availableProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getAvailableProducts();
});

/// Featured Products Provider
/// Fetches featured products for the home page (limited to 6)
final featuredProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getFeaturedProducts(limit: 6);
});

/// Products by Category Provider
/// Fetches products filtered by category
final productsByCategoryProvider =
    FutureProvider.family<List<Product>, String?>((ref, category) async {
  final repository = ref.watch(productRepositoryProvider);

  if (category == null || category.isEmpty) {
    return repository.getAvailableProducts();
  }

  return repository.getProductsByCategory(category);
});

/// Single Product Provider
/// Fetches a single product by ID
final productByIdProvider =
    FutureProvider.family<Product?, String>((ref, productId) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductById(productId);
});

/// Search Products Provider
/// Searches products by query
final searchProductsProvider =
    FutureProvider.family<List<Product>, String>((ref, query) async {
  final repository = ref.watch(productRepositoryProvider);

  if (query.isEmpty) {
    return repository.getAvailableProducts();
  }

  return repository.searchProducts(query);
});

/// Product Availability Provider
/// Checks if a product is available for a date range
final productAvailabilityProvider =
    FutureProvider.family<bool, ProductAvailabilityParams>((ref, params) async {
  final repository = ref.watch(productRepositoryProvider);
  return repository.checkAvailability(
    productId: params.productId,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

/// Helper class for product availability parameters
class ProductAvailabilityParams {
  final String productId;
  final DateTime startDate;
  final DateTime endDate;

  ProductAvailabilityParams({
    required this.productId,
    required this.startDate,
    required this.endDate,
  });
}
