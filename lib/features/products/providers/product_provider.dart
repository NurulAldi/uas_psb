import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/products/data/repositories/product_repository.dart';
import 'package:rentlens/features/products/domain/models/product.dart';
import 'package:rentlens/features/auth/providers/auth_provider.dart' as auth;

/// Product Repository Provider
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository();
});

/// All Products Provider
/// Fetches all products from Supabase
final allProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  // Depend on current user so results are refreshed on auth change
  ref.watch(auth.currentUserProvider);
  final repository = ref.watch(productRepositoryProvider);
  return repository.getProducts();
});

/// Available Products Provider
/// Fetches only available products
final availableProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  // Depend on current user so results are refreshed on auth change
  ref.watch(auth.currentUserProvider);
  final repository = ref.watch(productRepositoryProvider);
  return repository.getAvailableProducts();
});

/// Featured Products Provider
/// Fetches featured products for the home page (limited to 6)
final featuredProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  // Depend on current user so results are refreshed on auth change
  ref.watch(auth.currentUserProvider);
  final repository = ref.watch(productRepositoryProvider);
  return repository.getFeaturedProducts(limit: 6);
});

/// Products by Category Provider
/// Fetches products filtered by category
final productsByCategoryProvider =
    FutureProvider.autoDispose.family<List<Product>, String?>((ref, category) async {
  // Depend on current user so results refresh on auth changes
  ref.watch(auth.currentUserProvider);

  final repository = ref.watch(productRepositoryProvider);

  if (category == null || category.isEmpty) {
    return repository.getAvailableProducts();
  }

  return repository.getProductsByCategory(category);
});

/// Single Product Provider
/// Fetches a single product by ID
final productByIdProvider =
    FutureProvider.autoDispose.family<Product?, String>((ref, productId) async {
  // Depend on current user so product details refresh on auth change (owner visibility)
  ref.watch(auth.currentUserProvider);

  final repository = ref.watch(productRepositoryProvider);
  return repository.getProductById(productId);
});

/// Search Products Provider
/// Searches products by query
final searchProductsProvider =
    FutureProvider.autoDispose.family<List<Product>, String>((ref, query) async {
  // Depend on current user so search results refresh on auth changes
  ref.watch(auth.currentUserProvider);

  final repository = ref.watch(productRepositoryProvider);

  if (query.isEmpty) {
    return repository.getAvailableProducts();
  }

  return repository.searchProducts(query);
});

// Check if current user is the owner of the product
// This provider watches the auth state so it will recompute on logout/login
final isProductOwnerProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, productId) async {
  // Depend on current user provider to invalidate when auth changes
  final currentUser = ref.watch(auth.currentUserProvider);
  if (currentUser == null) return false;

  final repository = ref.watch(productRepositoryProvider);
  return repository.isUserOwner(productId);
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
