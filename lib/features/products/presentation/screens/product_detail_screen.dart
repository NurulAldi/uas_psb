import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/core/constants/app_strings.dart';
import 'package:rentlens/core/utils/navigation_helper.dart';
import 'package:rentlens/features/products/providers/product_provider.dart';
import 'package:rentlens/features/products/domain/models/product.dart';
import 'package:rentlens/features/admin/presentation/widgets/report_user_dialog.dart';
import 'package:rentlens/features/auth/providers/profile_provider.dart';
import 'package:rentlens/features/auth/providers/auth_provider.dart' as auth;
import 'package:rentlens/features/products/presentation/widgets/zoomable_image_viewer.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByIdProvider(productId));

    return productAsync.when(
      data: (product) {
        if (product == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off,
                      size: 64, color: AppColors.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.productNotFound,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.productNotFoundMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => NavigationHelper.popOrNavigate(
                      context,
                      fallbackRoute: '/',
                    ),
                    child: const Text(AppStrings.goHome),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: _buildProductDetail(context, ref, product),
          bottomNavigationBar: _BottomActionBar(product: product),
        );
      },
      loading: () => Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Gagal memuat produk',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () =>
                          ref.refresh(productByIdProvider(productId)),
                      child: const Text('Retry'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: () => NavigationHelper.popOrNavigate(
                        context,
                        fallbackRoute: '/',
                      ),
                      child: const Text(AppStrings.goHome),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetail(
      BuildContext context, WidgetRef ref, Product product) {
    return CustomScrollView(
      slivers: [
        // App Bar with Image Gallery
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => NavigationHelper.popOrNavigate(
              context,
              fallbackRoute: '/',
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: product.imageUrls.isNotEmpty
                ? _ImageGallery(
                    imageUrls: product.imageUrls,
                  )
                : Container(
                    color: AppColors.backgroundGrey,
                    child: Center(
                      child: Icon(
                        Icons.camera_alt,
                        size: 100,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
          ),
          actions: [
            // Report button (only for non-owners)
            Consumer(
              builder: (context, ref, child) {
                final authState = ref.watch(auth.authProvider);

                // Only proceed if authenticated and product has an owner
                if (!authState.isAuthenticated || product.ownerId == null)
                  return const SizedBox.shrink();

                final ownerAsync =
                    ref.watch(isProductOwnerProvider(product.id));

                return ownerAsync.when(
                  data: (isOwner) {
                    if (!isOwner) {
                      return IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadow,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.flag,
                              size: 20, color: Colors.red[700]),
                        ),
                        onPressed: () =>
                            _showReportDialog(context, ref, product),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),

        // Product Details
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(product.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    product.category.value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _getCategoryColor(product.category),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),

                const SizedBox(height: 16),

                // Product Name
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),

                const SizedBox(height: 16),

                // Price Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundGrey,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.rentalPrice,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.formattedPrice,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                          ),
                        ],
                      ),
                      Text(
                        'per hari',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Availability Status
                Row(
                  children: [
                    Icon(
                      product.isAvailable ? Icons.check_circle : Icons.cancel,
                      color: product.isAvailable
                          ? AppColors.success
                          : AppColors.error,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      product.isAvailable
                          ? 'Tersedia untuk disewa'
                          : 'Sedang tidak tersedia',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: product.isAvailable
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // Description Section
                Text(
                  'Deskripsi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  product.description ??
                      'Tidak ada deskripsi untuk produk ini.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // Owner Section
                Consumer(
                  builder: (context, ref, child) {
                    final authState = ref.watch(auth.authProvider);
                    final isOwner = authState.isAuthenticated &&
                        authState.userProfile != null &&
                        authState.userProfile!.id == product.ownerId;

                    // Only show owner section if user is authenticated and not the owner
                    if (product.ownerId != null && authState.isAuthenticated) {
                      final ownerAsync =
                          ref.watch(isProductOwnerProvider(product.id));
                      return ownerAsync.when(
                        data: (isOwner) => !isOwner
                            ? _OwnerInfoSection(ownerId: product.ownerId!)
                            : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Show report dialog
  Future<void> _showReportDialog(
      BuildContext context, WidgetRef ref, Product product) async {
    if (product.ownerId == null) return;

    // Get product owner profile to get name
    final owner = await ref
        .read(profileByIdProvider(product.ownerId!).future)
        .catchError((_) => null);

    if (!context.mounted) return;

    await showDialog<bool>(
      context: context,
      builder: (context) => ReportUserDialog(
        reportedUserId: product.ownerId!,
        reportedUserName: owner?.fullName ?? AppStrings.productOwner,
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

/// Owner Info Section Widget
class _OwnerInfoSection extends ConsumerWidget {
  final String ownerId;

  const _OwnerInfoSection({required this.ownerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerAsync = ref.watch(profileByIdProvider(ownerId));

    return ownerAsync.when(
      data: (owner) {
        if (owner == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.owner,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                context.push('/profile/$ownerId');
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGrey,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary,
                      child: owner.avatarUrl != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: owner.avatarUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.white,
                            ),
                    ),
                    const SizedBox(width: 16),
                    // Owner info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            owner.fullName ?? AppStrings.owner,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (owner.city != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  owner.city!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // Arrow icon
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Bottom action bar for booking
class _BottomActionBar extends ConsumerStatefulWidget {
  final Product product;

  const _BottomActionBar({required this.product});

  @override
  ConsumerState<_BottomActionBar> createState() => _BottomActionBarState();
}

class _BottomActionBarState extends ConsumerState<_BottomActionBar> {
  @override
  Widget build(BuildContext context) {
    // Compute ownership inside build so the widget reacts to auth changes
    final ownerAsync = ref.watch(isProductOwnerProvider(widget.product.id));

    return ownerAsync.when(
      data: (isOwner) {
        if (isOwner) {
          return _buildOwnerActionBar(context);
        }

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            widget.product.isAvailable ? _handleRentNow : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          disabledBackgroundColor: AppColors.textTertiary,
                        ),
                        child: Text(
                          widget.product.isAvailable
                              ? 'Sewa Sekarang'
                              : 'Tidak Tersedia',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Action Buttons (disabled while loading)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: AppColors.textTertiary,
                      ),
                      child: Text(
                        widget.product.isAvailable
                            ? 'Sewa Sekarang'
                            : 'Tidak Tersedia',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          widget.product.isAvailable ? _handleRentNow : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: AppColors.textTertiary,
                      ),
                      child: Text(
                        widget.product.isAvailable
                            ? 'Sewa Sekarang'
                            : 'Tidak Tersedia',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Handle book now button
  Future<void> _handleRentNow() async {
    // Navigate to booking form screen
    context.push(
      '/bookings/new?productId=${widget.product.id}',
    );
  }

  /// Build action bar for product owner
  Widget _buildOwnerActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Owner indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppStrings.thisIsYourProduct,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Edit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push('/products/${widget.product.id}/edit',
                      extra: widget.product);
                },
                icon: const Icon(Icons.edit),
                label: const Text(AppStrings.editProduct),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Image Gallery Widget with PageView and Thumbnails
class _ImageGallery extends StatefulWidget {
  final List<String> imageUrls;

  const _ImageGallery({required this.imageUrls});

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _showThumbnails = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullScreenViewer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ZoomableImageViewer(
          imageUrls: widget.imageUrls,
          initialIndex: _currentIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main Image PageView with Gesture Zoom
        PageView.builder(
          controller: _pageController,
          itemCount: widget.imageUrls.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
              // Show thumbnails briefly when changing page
              _showThumbnails = true;
            });
            // Hide thumbnails after 2 seconds
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  _showThumbnails = false;
                });
              }
            });
          },
          itemBuilder: (context, index) {
            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              onInteractionStart: (details) {
                // Show thumbnails when user starts interacting
                setState(() {
                  _showThumbnails = true;
                });
              },
              onInteractionEnd: (details) {
                // Hide thumbnails after interaction ends
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    setState(() {
                      _showThumbnails = false;
                    });
                  }
                });
              },
              child: GestureDetector(
                onDoubleTap: () => _openFullScreenViewer(context),
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrls[index],
                    fit: BoxFit.contain, // Full scale, no crop
                    placeholder: (context, url) => Container(
                      color: AppColors.backgroundGrey,
                      child: Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.backgroundGrey,
                      child: Center(
                        child: Icon(
                          Icons.camera_alt,
                          size: 100,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Image counter
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentIndex + 1}/${widget.imageUrls.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Thumbnail navigation (bottom) - only show when interacting
        if (widget.imageUrls.length > 1)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            bottom: _showThumbnails ? 16 : -80,
            left: 16,
            right: 16,
            child: SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.imageUrls.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _currentIndex;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.white54,
                          width: isSelected ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrls[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.error,
                              color: Colors.white54,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
