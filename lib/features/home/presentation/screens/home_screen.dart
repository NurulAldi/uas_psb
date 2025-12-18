import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/core/constants/app_strings.dart';
import 'package:rentlens/features/products/domain/models/product.dart';
import 'package:rentlens/features/products/domain/models/product_with_distance.dart';
import 'package:rentlens/features/auth/controllers/auth_controller.dart';
import 'package:rentlens/features/auth/providers/profile_provider.dart';
import 'package:rentlens/features/auth/presentation/widgets/user_avatar.dart';
import 'package:rentlens/features/products/providers/location_aware_product_provider.dart';
import 'package:rentlens/features/products/presentation/widgets/location_permission_banner.dart';
import 'package:rentlens/features/products/presentation/widgets/location_status_header.dart';
import 'package:rentlens/features/products/presentation/widgets/no_nearby_products_widget.dart';
import 'package:rentlens/features/products/presentation/widgets/product_distance_badge.dart';

/// Home Screen - Location-First Product Discovery
/// Default view shows nearby products within configurable radius
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state for user profile
    final authAsync = ref.watch(authStateProvider);
    final userProfile = authAsync.value?.user;

    // Watch location-aware product state
    final productState = ref.watch(locationAwareProductControllerProvider);
    final controller =
        ref.read(locationAwareProductControllerProvider.notifier);

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
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text(AppStrings.logout),
                    content: const Text(AppStrings.logoutConfirmation),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(AppStrings.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(AppStrings.logout),
                      ),
                    ],
                  ),
                );
                if (shouldLogout == true) {
                  await ref.read(authControllerProvider.notifier).signOut();
                }
              } else if (value == 'my-listings') {
                context.push('/products/my-listings');
              } else if (value == 'edit-profile') {
                if (userProfile != null) {
                  await context.push('/edit-profile', extra: userProfile);
                }
              } else if (value == 'my-bookings') {
                context.push('/bookings');
              } else if (value == 'booking-requests') {
                context.push('/owner/bookings');
              }
            },
            itemBuilder: (context) => [
              if (userProfile != null)
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userProfile.fullName ??
                            userProfile.email ??
                            AppStrings.user,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userProfile.email ?? '',
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
                    Text(AppStrings.editProfile),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'my-bookings',
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, size: 18),
                    SizedBox(width: 8),
                    Text(AppStrings.myBookings),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'booking-requests',
                child: Row(
                  children: [
                    Icon(Icons.inbox, size: 18),
                    SizedBox(width: 8),
                    Text(AppStrings.bookingRequests),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'my-listings',
                child: Row(
                  children: [
                    Icon(Icons.list_alt, size: 18),
                    SizedBox(width: 8),
                    Text(AppStrings.myListings),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text(AppStrings.logout),
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
      body: RefreshIndicator(
        onRefresh: () => controller.refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location permission check
              if (productState.permissionDenied)
                LocationPermissionBanner(
                  onRequestPermission: () =>
                      controller.requestLocationPermission(),
                  isPermanentlyDenied: productState.permissionStatus ==
                      LocationPermissionStatus.deniedPermanently,
                ),

              // Location status header (when location available)
              if (productState.hasLocation)
                LocationStatusHeader(
                  cityName: userProfile?.city,
                  radiusKm: productState.radiusKm,
                  productCount: productState.productCount,
                  onAdjustRadius: () => _showRadiusDialog(
                      context, controller, productState.radiusKm),
                  onRefresh: () => controller.refresh(),
                ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => controller.updateSearch(value),
                  decoration: InputDecoration(
                    hintText: AppStrings.searchNearbyProducts,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: productState.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              controller.updateSearch('');
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

              // Category Filter
              _buildCategoryFilter(controller, productState),

              const SizedBox(height: 16),

              // Products Section
              _buildProductsSection(productState, controller, context),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Build category filter chips
  Widget _buildCategoryFilter(
    LocationAwareProductController controller,
    LocationAwareProductState state,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildCategoryChip(
            label: AppStrings.allCategories,
            icon: Icons.select_all,
            color: AppColors.primary,
            isSelected: state.selectedCategory == null,
            onTap: () => controller.clearCategory(),
          ),
          const SizedBox(width: 8),
          _buildCategoryChip(
            label: AppStrings.categoryDSLR,
            icon: Icons.camera,
            color: AppColors.categoryDSLR,
            isSelected: state.selectedCategory == ProductCategory.dslr,
            onTap: () => controller.updateCategory(ProductCategory.dslr),
          ),
          const SizedBox(width: 8),
          _buildCategoryChip(
            label: AppStrings.categoryMirrorless,
            icon: Icons.camera_alt,
            color: AppColors.categoryMirrorless,
            isSelected: state.selectedCategory == ProductCategory.mirrorless,
            onTap: () => controller.updateCategory(ProductCategory.mirrorless),
          ),
          const SizedBox(width: 8),
          _buildCategoryChip(
            label: 'Drone',
            icon: Icons.flight,
            color: AppColors.categoryDrone,
            isSelected: state.selectedCategory == ProductCategory.drone,
            onTap: () => controller.updateCategory(ProductCategory.drone),
          ),
          const SizedBox(width: 8),
          _buildCategoryChip(
            label: AppStrings.categoryLens,
            icon: Icons.lens,
            color: AppColors.categoryLens,
            isSelected: state.selectedCategory == ProductCategory.lens,
            onTap: () => controller.updateCategory(ProductCategory.lens),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? color.withOpacity(0.15) : Colors.grey[100],
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isSelected ? color : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build products section
  Widget _buildProductsSection(
    LocationAwareProductState state,
    LocationAwareProductController controller,
    BuildContext context,
  ) {
    // Loading state
    if (state.isLoading) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Mencari kamera terdekat...',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Error state
    if (state.error != null && !state.hasLocation) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Tidak dapat mendapatkan lokasi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => controller.retry(),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      );
    }

    // No products state
    if (state.hasLocation && !state.hasProducts) {
      return NoNearbyProductsWidget(
        currentRadius: state.radiusKm,
        onIncreaseRadius: () {
          final nextRadius = _getNextRadius(state.radiusKm);
          if (nextRadius != null) {
            controller.updateRadius(nextRadius);
          }
        },
        onRefresh: () => controller.refresh(),
      );
    }

    // Products list
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.searchQuery.isNotEmpty
                    ? 'Hasil Pencarian'
                    : state.selectedCategory != null
                        ? 'Kamera ${state.selectedCategory!.value}'
                        : 'Kamera Terdekat',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Product count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${state.productCount} produk ditemukan dalam radius ${state.radiusKm} km',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Products grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
            itemCount: state.products.length,
            itemBuilder: (context, index) {
              final product = state.products[index];
              return _ProductCardWithDistance(
                key: ValueKey(product.id),
                product: product,
                onTap: () => context.push('/products/${product.id}'),
              );
            },
          ),
        ),
      ],
    );
  }

  double? _getNextRadius(double current) {
    const options = [10.0, 20.0, 30.0, 40.0, 50.0];
    final index = options.indexOf(current);
    if (index >= 0 && index < options.length - 1) {
      return options[index + 1];
    }
    return null;
  }

  void _showRadiusDialog(
    BuildContext context,
    LocationAwareProductController controller,
    double currentRadius,
  ) {
    double selectedRadius = currentRadius;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Atur Radius Pencarian'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${selectedRadius.toStringAsFixed(0)} km',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: selectedRadius,
                min: 5.0,
                max: 50.0,
                divisions: 9,
                label: '${selectedRadius.toStringAsFixed(0)} km',
                onChanged: (value) {
                  setState(() {
                    selectedRadius = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('5 km',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('50 km',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                controller.updateRadius(selectedRadius);
                Navigator.pop(context);
              },
              child: const Text('Terapkan'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Product card with distance information
class _ProductCardWithDistance extends StatelessWidget {
  final ProductWithDistance product;
  final VoidCallback onTap;

  const _ProductCardWithDistance({
    super.key,
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

                  // Distance Badge (top-right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ProductDistanceBadge(
                        distanceKm: product.distanceKm,
                        compact: true,
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
              style: TextStyle(
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
            style: TextStyle(
              fontSize: 14,
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                ' / hari',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
