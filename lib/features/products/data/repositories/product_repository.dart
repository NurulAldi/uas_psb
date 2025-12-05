import 'package:rentlens/core/config/supabase_config.dart';
import 'package:rentlens/features/products/domain/models/product.dart';

/// Product Repository
/// Handles all data operations related to products
class ProductRepository {
  final _supabase = SupabaseConfig.client;

  /// Fetch all products
  Future<List<Product>> getProducts() async {
    try {
      print('📦 PRODUCT REPOSITORY: Fetching all products...');

      final response = await _supabase
          .from('products')
          .select()
          .order('created_at', ascending: false);

      print('📦 PRODUCT REPOSITORY: Received ${response.length} products');

      final products = (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      return products;
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error fetching products = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Fetch products by category
  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      print('📦 PRODUCT REPOSITORY: Fetching products by category: $category');

      final response = await _supabase
          .from('products')
          .select()
          .eq('category', category)
          .order('created_at', ascending: false);

      print(
          '📦 PRODUCT REPOSITORY: Received ${response.length} products for category $category');

      final products = (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      return products;
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error fetching products by category = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Fetch available products only
  Future<List<Product>> getAvailableProducts() async {
    try {
      print('📦 PRODUCT REPOSITORY: Fetching available products...');

      final response = await _supabase
          .from('products')
          .select()
          .eq('is_available', true)
          .order('created_at', ascending: false);

      print(
          '📦 PRODUCT REPOSITORY: Received ${response.length} available products');

      final products = (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      return products;
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error fetching available products = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Fetch a single product by ID
  Future<Product?> getProductById(String productId) async {
    try {
      print('📦 PRODUCT REPOSITORY: Fetching product with ID: $productId');

      final response = await _supabase
          .from('products')
          .select()
          .eq('id', productId)
          .single();

      print('📦 PRODUCT REPOSITORY: Product found: ${response['name']}');

      return Product.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error fetching product by ID = $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Search products by name
  Future<List<Product>> searchProducts(String query) async {
    try {
      print('📦 PRODUCT REPOSITORY: Searching products with query: $query');

      final response = await _supabase
          .from('products')
          .select()
          .ilike('name', '%$query%')
          .order('created_at', ascending: false);

      print(
          '📦 PRODUCT REPOSITORY: Found ${response.length} products matching "$query"');

      final products = (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      return products;
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error searching products = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get featured products (first 6 available products)
  Future<List<Product>> getFeaturedProducts({int limit = 6}) async {
    try {
      print(
          '📦 PRODUCT REPOSITORY: Fetching featured products (limit: $limit)...');

      final response = await _supabase
          .from('products')
          .select()
          .eq('is_available', true)
          .order('created_at', ascending: false)
          .limit(limit);

      print(
          '📦 PRODUCT REPOSITORY: Received ${response.length} featured products');

      final products = (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      return products;
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error fetching featured products = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check product availability for date range
  Future<bool> checkAvailability({
    required String productId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print(
          '📦 PRODUCT REPOSITORY: Checking availability for product $productId');

      // First check if product exists and is available
      final product = await getProductById(productId);
      if (product == null || !product.isAvailable) {
        return false;
      }

      // Check for overlapping bookings
      final response = await _supabase
          .from('bookings')
          .select()
          .eq('product_id', productId)
          .inFilter('status', ['pending', 'confirmed', 'active']).or(
              'start_date.lte.$endDate,end_date.gte.$startDate');

      print(
          '📦 PRODUCT REPOSITORY: Found ${response.length} conflicting bookings');

      return response.isEmpty;
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error checking availability = $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  // =====================================================
  // P2P MARKETPLACE METHODS
  // =====================================================

  /// Get products owned by current user
  Future<List<Product>> getMyProducts() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        throw Exception('No authenticated user');
      }

      print('📦 PRODUCT REPOSITORY: Fetching products for user: $userId');

      // Try to fetch with owner_id filter
      try {
        final response = await _supabase
            .from('products')
            .select()
            .eq('owner_id', userId)
            .order('created_at', ascending: false);

        print('📦 PRODUCT REPOSITORY: User has ${response.length} products');

        final products = (response as List)
            .map((json) => Product.fromJson(json as Map<String, dynamic>))
            .toList();

        return products;
      } catch (e) {
        // If owner_id column doesn't exist, throw helpful error
        if (e.toString().contains('owner_id') ||
            e.toString().contains('column')) {
          throw Exception('Database migration required!\n\n'
              'Please run the P2P marketplace migration SQL script:\n'
              '1. Open Supabase Dashboard\n'
              '2. Go to SQL Editor\n'
              '3. Run: supabase_migration_p2p_marketplace.sql\n\n'
              'This will add the owner_id column to products table.');
        }
        rethrow;
      }
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error fetching user products = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Create a new product listing
  Future<Product> createProduct({
    required String name,
    required String category,
    required double pricePerDay,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        throw Exception('No authenticated user');
      }

      print('📦 PRODUCT REPOSITORY: Creating product...');
      print('   Name: $name');
      print('   Category: $category');
      print('   Price: $pricePerDay');
      print('   Owner: $userId');

      final productData = {
        'name': name,
        'category': category,
        'description': description,
        'price_per_day': pricePerDay,
        'image_url': imageUrl,
        'is_available': true,
        'owner_id': userId,
      };

      final response = await _supabase
          .from('products')
          .insert(productData)
          .select()
          .single();

      print('✅ PRODUCT REPOSITORY: Product created successfully');
      print('   Product ID: ${response['id']}');

      return Product.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error creating product = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Update a product (owner only)
  Future<Product> updateProduct({
    required String productId,
    String? name,
    String? category,
    double? pricePerDay,
    String? description,
    String? imageUrl,
    bool? isAvailable,
  }) async {
    try {
      print('📦 PRODUCT REPOSITORY: Updating product: $productId');

      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (category != null) updates['category'] = category;
      if (pricePerDay != null) updates['price_per_day'] = pricePerDay;
      if (description != null) updates['description'] = description;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (isAvailable != null) updates['is_available'] = isAvailable;

      if (updates.isEmpty) {
        throw Exception('No updates provided');
      }

      final response = await _supabase
          .from('products')
          .update(updates)
          .eq('id', productId)
          .select()
          .single();

      print('✅ PRODUCT REPOSITORY: Product updated successfully');

      return Product.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error updating product = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete a product (owner only)
  Future<void> deleteProduct(String productId) async {
    try {
      print('📦 PRODUCT REPOSITORY: Deleting product: $productId');

      await _supabase.from('products').delete().eq('id', productId);

      print('✅ PRODUCT REPOSITORY: Product deleted successfully');
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error deleting product = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
