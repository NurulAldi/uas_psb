import 'package:rentlens/core/config/supabase_config.dart';
import 'package:rentlens/features/products/domain/models/product.dart';
import 'package:rentlens/features/products/domain/models/product_with_distance.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Check whether the currently authenticated user is the owner of the product
  /// Returns false if there's no authenticated user or on error
  Future<bool> isUserOwner(String productId) async {
    try {
      final currentUserId = await SupabaseConfig.currentUserId;
      if (currentUserId == null) return false;

      // Set user context for RLS (defensive)
      await _supabase
          .rpc('set_user_context', params: {'user_id': currentUserId});

      final response = await _supabase
          .from('products')
          .select('owner_id')
          .eq('id', productId)
          .maybeSingle();

      if (response == null) return false;

      final ownerId = response['owner_id'] as String?;
      return ownerId != null && ownerId == currentUserId;
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error checking product ownership = $e');
      print('Stack trace: $stackTrace');
      return false;
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
      final userId = await SupabaseConfig.currentUserId;
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
    List<String>? imageUrls,
  }) async {
    try {
      final userId = await SupabaseConfig.currentUserId;
      if (userId == null) {
        throw Exception('No authenticated user');
      }

      print('📦 PRODUCT REPOSITORY: Creating product...');
      print('   Name: $name');
      print('   Category: $category');
      print('   Price: $pricePerDay');
      print('   Owner: $userId');

      // Set user context for RLS policies
      await _supabase.rpc('set_user_context', params: {'user_id': userId});

      final productData = {
        'name': name,
        'category': category,
        'description': description,
        'price_per_day': pricePerDay,
        'image_url': imageUrl,
        'image_urls': imageUrls ?? [],
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
    List<String>? imageUrls,
    bool? isAvailable,
  }) async {
    try {
      final currentUserId = await SupabaseConfig.currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      print('📦 PRODUCT REPOSITORY: Updating product: $productId');

      // Set user context for RLS policies
      await _supabase
          .rpc('set_user_context', params: {'user_id': currentUserId});

      // First, check if the product exists and belongs to the user
      final existingProduct = await _supabase
          .from('products')
          .select('id, name, owner_id')
          .eq('id', productId)
          .maybeSingle();

      if (existingProduct == null) {
        print('❌ PRODUCT REPOSITORY: Product $productId not found');
        throw Exception(
            'Product not found or you do not have permission to update it');
      }

      print(
          '📦 PRODUCT REPOSITORY: Found product: ${existingProduct['name']} (owner: ${existingProduct['owner_id']})');

      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (category != null) updates['category'] = category;
      if (pricePerDay != null) updates['price_per_day'] = pricePerDay;
      if (description != null) updates['description'] = description;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (imageUrls != null) updates['image_urls'] = imageUrls;
      if (isAvailable != null) updates['is_available'] = isAvailable;

      if (updates.isEmpty) {
        throw Exception('No updates provided');
      }

      // Perform the update
      final updateResult = await _supabase
          .from('products')
          .update(updates)
          .eq('id', productId)
          .select();

      print(
          '📦 PRODUCT REPOSITORY: Update affected ${updateResult.length} rows');

      if (updateResult.isEmpty) {
        print(
            '❌ PRODUCT REPOSITORY: No rows updated - possible RLS or permission issue');
        throw Exception('Failed to update product - no rows affected');
      }

      // Get the updated product data
      final updatedProduct = updateResult.first;
      print('✅ PRODUCT REPOSITORY: Product updated successfully');
      print('   Updated fields: ${updates.keys.join(', ')}');

      return Product.fromJson(updatedProduct);
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error updating product = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete a product (owner only)
  Future<void> deleteProduct(String productId) async {
    try {
      final currentUserId = await SupabaseConfig.currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      print('📦 PRODUCT REPOSITORY: Deleting product: $productId');

      // Set user context for RLS policies
      await _supabase
          .rpc('set_user_context', params: {'user_id': currentUserId});

      await _supabase.from('products').delete().eq('id', productId);

      print('✅ PRODUCT REPOSITORY: Product deleted successfully');
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error deleting product = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get nearby products (PRIMARY METHOD - Location-first discovery)
  /// Uses enhanced Supabase RPC function with search and filter support
  Future<List<ProductWithDistance>> getNearbyProducts({
    required double latitude,
    required double longitude,
    double radiusKm = 20.0,
    String? searchText,
    ProductCategory? category,
  }) async {
    try {
      print('📍 PRODUCT REPOSITORY: Fetching nearby products...');
      print('   User location: ($latitude, $longitude)');
      print('   Radius: ${radiusKm}km');
      if (searchText != null) print('   Search: "$searchText"');
      if (category != null) print('   Category: $category');

      // Get current user ID to exclude own products
      final currentUserId = await SupabaseConfig.currentUserId;

      final params = {
        'user_lat': latitude,
        'user_lon': longitude,
        'radius_km': radiusKm,
        if (searchText != null && searchText.isNotEmpty)
          'search_text': searchText,
        if (category != null) 'filter_category': category.value,
        if (currentUserId != null) 'exclude_user_id': currentUserId,
      };

      final response = await _supabase.rpc(
        'get_nearby_products',
        params: params,
      );

      print('📍 PRODUCT REPOSITORY: Found ${response.length} nearby products');

      final products = (response as List)
          .map((json) =>
              ProductWithDistance.fromJson(json as Map<String, dynamic>))
          .toList();

      // Products are already sorted by distance in SQL, but ensure it
      products.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      return products;
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error fetching nearby products = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get products without location (FALLBACK ONLY - used when location unavailable)
  /// Shows warning that this is degraded experience
  @Deprecated('Use getNearbyProducts() instead - location-first is the default')
  Future<List<Product>> getProductsWithoutLocation() async {
    try {
      print(
          '⚠️ PRODUCT REPOSITORY: Fetching products WITHOUT location filtering');
      print('   This is a degraded experience - location should be enabled');

      final response = await _supabase
          .from('products')
          .select()
          .eq('is_available', true)
          .order('created_at', ascending: false)
          .limit(50); // Limit for performance

      print(
          '📦 PRODUCT REPOSITORY: Received ${response.length} products (no location filter)');

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

  /// Get distance to a specific product from user location
  Future<double?> getProductDistance({
    required String productId,
    required double userLat,
    required double userLon,
  }) async {
    try {
      final distance = await _supabase.rpc(
        'get_product_distance',
        params: {
          'product_id': productId,
          'user_lat': userLat,
          'user_lon': userLon,
        },
      );

      return distance as double?;
    } catch (e) {
      print('❌ PRODUCT REPOSITORY: Error getting product distance = $e');
      return null;
    }
  }

  /// Test the products_with_location view (for debugging location issues)
  Future<Map<String, dynamic>> testLocationView() async {
    try {
      print('🧪 PRODUCT REPOSITORY: Testing products_with_location view...');

      // Test 1: Count products in view
      final viewCountResponse = await _supabase
          .from('products_with_location')
          .select('id')
          .count(CountOption.exact);

      final viewCount = viewCountResponse.count ?? 0;

      // Test 2: Count products with location in base tables
      final productsResponse = await _supabase
          .from('products')
          .select('''
            id,
            owner_id,
            users!inner(
              id,
              username,
              latitude,
              longitude,
              city
            )
          ''')
          .eq('is_available', true)
          .not('users.latitude', 'is', null)
          .not('users.longitude', 'is', null);

      final tableCount = (productsResponse as List).length;

      print(
          '🧪 PRODUCT REPOSITORY: View count: $viewCount, Table count: $tableCount');

      return {
        'view_count': viewCount,
        'table_count': tableCount,
        'view_working': viewCount > 0,
        'data_consistent': viewCount == tableCount,
        'sample_products': productsResponse.take(3).toList(),
      };
    } catch (e, stackTrace) {
      print('❌ PRODUCT REPOSITORY: Error testing location view = $e');
      print('Stack trace: $stackTrace');
      return {
        'error': e.toString(),
        'view_working': false,
        'data_consistent': false,
      };
    }
  }
}
