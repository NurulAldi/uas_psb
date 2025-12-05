import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/products/data/repositories/product_repository.dart';
import 'package:rentlens/features/products/domain/models/product.dart';
import 'package:rentlens/features/products/providers/product_provider.dart';

/// Provider for user's products (my listings)
final myProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getMyProducts();
});

/// State notifier for managing product creation/updates
class ProductManagementController extends StateNotifier<AsyncValue<void>> {
  final ProductRepository _repository;

  ProductManagementController(this._repository)
      : super(const AsyncValue.data(null));

  /// Create a new product
  Future<Product?> createProduct({
    required String name,
    required String category,
    required double pricePerDay,
    String? description,
    String? imageUrl,
  }) async {
    state = const AsyncValue.loading();

    try {
      print('🎬 PRODUCT MANAGEMENT: Creating product...');

      final product = await _repository.createProduct(
        name: name,
        category: category,
        pricePerDay: pricePerDay,
        description: description,
        imageUrl: imageUrl,
      );

      state = const AsyncValue.data(null);
      print('✅ PRODUCT MANAGEMENT: Product created successfully');
      return product;
    } catch (e, stackTrace) {
      print('❌ PRODUCT MANAGEMENT: Error creating product = $e');
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Update an existing product
  Future<Product?> updateProduct({
    required String productId,
    String? name,
    String? category,
    double? pricePerDay,
    String? description,
    String? imageUrl,
    bool? isAvailable,
  }) async {
    state = const AsyncValue.loading();

    try {
      print('🎬 PRODUCT MANAGEMENT: Updating product...');

      final product = await _repository.updateProduct(
        productId: productId,
        name: name,
        category: category,
        pricePerDay: pricePerDay,
        description: description,
        imageUrl: imageUrl,
        isAvailable: isAvailable,
      );

      state = const AsyncValue.data(null);
      print('✅ PRODUCT MANAGEMENT: Product updated successfully');
      return product;
    } catch (e, stackTrace) {
      print('❌ PRODUCT MANAGEMENT: Error updating product = $e');
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Delete a product
  Future<bool> deleteProduct(String productId) async {
    state = const AsyncValue.loading();

    try {
      print('🎬 PRODUCT MANAGEMENT: Deleting product...');

      await _repository.deleteProduct(productId);

      state = const AsyncValue.data(null);
      print('✅ PRODUCT MANAGEMENT: Product deleted successfully');
      return true;
    } catch (e, stackTrace) {
      print('❌ PRODUCT MANAGEMENT: Error deleting product = $e');
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }
}

/// Provider for product management controller
final productManagementControllerProvider =
    StateNotifierProvider<ProductManagementController, AsyncValue<void>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return ProductManagementController(repository);
});
