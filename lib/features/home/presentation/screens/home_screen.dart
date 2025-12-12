import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/features/products/providers/product_provider.dart';
import 'package:rentlens/features/products/domain/models/product.dart';
import 'package:rentlens/features/auth/controllers/auth_controller.dart';
import 'package:rentlens/features/auth/providers/profile_provider.dart';
import 'package:rentlens/features/auth/presentation/widgets/user_avatar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ProductCategory? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentUser = authState.maybeWhen(
      data: (user) => user,
      orElse: () => null,
    );

    // Watch user profile for full name
    final profileAsync = ref.watch(currentUserProfileProvider);
    final userProfile = profileAsync.maybeWhen(
      data: (profile) => profile,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.camera_alt, color: AppColors.primary, size: 28),
            const SizedBox(width: 8),
            Text(
              'RentLens',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        actions: [
          // User menu
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(authControllerProvider.notifier).signOut();
              } else if (value == 'my-listings') {
                context.push('/products/my-listings');
              } else if (value == 'edit-profile') {
                if (userProfile != null) {
                  await context.push('/edit-profile', extra: userProfile);
                  // Profile will auto-refresh via provider invalidation
                }
              } else if (value == 'my-bookings') {
                context.push('/bookings');
              } else if (value == 'booking-requests') {
                context.push('/owner/bookings');
              } else if (value == 'admin-dashboard') {
                context.push('/admin/dashboard');
              }
            },
            itemBuilder: (context) => [
              if (currentUser != null)
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userProfile?.fullName ?? currentUser.email ?? 'User',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                            ),
                      ),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'edit-profile',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'my-bookings',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, size: 18),
                    SizedBox(width: 8),
                    Text('Pesanan Saya'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'booking-requests',
                child: Row(
                  children: [
                    Icon(Icons.inbox, size: 18),
                    SizedBox(width: 8),
                    Text('Booking Requests'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'my-listings',
                child: Row(
                  children: [
                    Icon(Icons.list_alt, size: 18),
                    SizedBox(width: 8),
                    Text('My Listings'),
                  ],
                ),
              ),
              // Admin Dashboard (only for admins)
              if (userProfile?.role == 'admin') ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'admin-dashboard',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings,
                          size: 18, color: Colors.deepPurple[700]),
                      const SizedBox(width: 8),
                      Text('Admin Dashboard',
                          style: TextStyle(
                              color: Colors.deepPurple[700],
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              child: UserAvatar(
                avatarUrl: userProfile?.avatarUrl,
                radius: 18,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar and Nearby Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search camera gear...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nearby Button
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.push('/nearby-products'),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.near_me,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Nearby',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Categories Filter Dropdown
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.category, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Kategori:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ProductCategory?>(
                        value: _selectedCategory,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down,
                            color: AppColors.primary),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                        items: [
                          DropdownMenuItem<ProductCategory?>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(Icons.select_all,
                                    size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                const Text('Semua Kategori'),
                              ],
                            ),
                          ),
                          DropdownMenuItem<ProductCategory?>(
                            value: ProductCategory.dslr,
                            child: Row(
                              children: [
                                Icon(Icons.camera,
                                    size: 18, color: AppColors.categoryDSLR),
                                const SizedBox(width: 8),
                                const Text('DSLR'),
                              ],
                            ),
                          ),
                          DropdownMenuItem<ProductCategory?>(
                            value: ProductCategory.mirrorless,
                            child: Row(
                              children: [
                                Icon(Icons.camera_alt,
                                    size: 18,
                                    color: AppColors.categoryMirrorless),
                                const SizedBox(width: 8),
                                const Text('Mirrorless'),
                              ],
                            ),
                          ),
                          DropdownMenuItem<ProductCategory?>(
                            value: ProductCategory.drone,
                            child: Row(
                              children: [
                                Icon(Icons.flight,
                                    size: 18, color: AppColors.categoryDrone),
                                const SizedBox(width: 8),
                                const Text('Drone'),
                              ],
                            ),
                          ),
                          DropdownMenuItem<ProductCategory?>(
                            value: ProductCategory.lens,
                            child: Row(
                              children: [
                                Icon(Icons.lens,
                                    size: 18, color: AppColors.categoryLens),
                                const SizedBox(width: 8),
                                const Text('Lens'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Products Section (with dynamic title based on filters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Search Results'
                        : _selectedCategory != null
                            ? '${_selectedCategory!.name.toUpperCase()} Products'
                            : 'All Products',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_searchQuery.isEmpty && _selectedCategory == null)
                    TextButton(
                      onPressed: () => context.push('/products'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        padding: EdgeInsets.zero,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'See all',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                          ),
                          const Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Products Grid
            _buildProductsGrid(ref, context),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Build products grid with real data from Supabase
  Widget _buildProductsGrid(WidgetRef ref, BuildContext context) {
    final productsAsync = ref.watch(featuredProductsProvider);

    return productsAsync.when(
      data: (products) {
        // Filter by category
        var filteredProducts = products;
        if (_selectedCategory != null) {
          filteredProducts =
              products.where((p) => p.category == _selectedCategory).toList();
        }

        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          filteredProducts = filteredProducts.where((p) {
            return p.name.toLowerCase().contains(query) ||
                (p.description?.toLowerCase().contains(query) ?? false) ||
                p.category.name.toLowerCase().contains(query);
          }).toList();
        }

        if (filteredProducts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off,
                      size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty || _selectedCategory != null
                        ? 'No products found'
                        : 'No products available yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty || _selectedCategory != null
                        ? 'Try adjusting your search or filter'
                        : 'Check back later for new camera equipment',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Result count
            if (_searchQuery.isNotEmpty || _selectedCategory != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  '${filteredProducts.length} ${filteredProducts.length == 1 ? 'product' : 'products'} found',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),

            // Products grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return _ProductCard(
                    product: product,
                    onTap: () => context.push('/products/${product.id}'),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Loading products...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat produk',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.error,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(featuredProductsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Stack(
                children: [
                  // Product Image
                  if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(
                            Icons.camera_alt,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Icon(
                        Icons.camera_alt,
                        size: 48,
                        color: AppColors.textTertiary,
                      ),
                    ),

                  // Availability Badge
                  if (!product.isAvailable)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Unavailable',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Category Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getCategoryColor(product.category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              product.category.value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getCategoryColor(product.category),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
            ),
          ),

          const SizedBox(height: 4),

          // Product Name
          Text(
            product.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Price
          Row(
            children: [
              Text(
                product.shortPrice,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
              Text(
                ' / hari',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get color for category badge
  Color _getCategoryColor(ProductCategory category) {
    switch (category) {
      case ProductCategory.dslr:
        return AppColors.categoryDSLR;
      case ProductCategory.mirrorless:
        return AppColors.categoryMirrorless;
      case ProductCategory.drone:
        return AppColors.categoryDrone;
      case ProductCategory.lens:
        return AppColors.categoryLens;
    }
  }
}
