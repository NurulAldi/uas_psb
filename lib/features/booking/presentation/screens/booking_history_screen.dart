import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/features/booking/providers/booking_provider.dart';
import 'package:rentlens/features/booking/domain/models/booking_with_product.dart';
import 'package:rentlens/features/booking/domain/models/booking.dart';
import 'package:rentlens/features/products/domain/models/product.dart';

class BookingHistoryScreen extends ConsumerWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(userBookingsWithProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking History'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(userBookingsWithProductsProvider);
            },
          ),
        ],
      ),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildBookingList(context, ref, bookings);
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => _buildErrorState(context, ref, error),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_outlined,
              size: 80,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 24),
            Text(
              'No Bookings Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your booking history will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.search),
              label: const Text('Browse Products'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load bookings',
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
            ElevatedButton(
              onPressed: () => ref.refresh(userBookingsWithProductsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingList(
    BuildContext context,
    WidgetRef ref,
    List<BookingWithProduct> bookings,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userBookingsWithProductsProvider);
      },
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return _BookingCard(bookingWithProduct: booking);
        },
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  final BookingWithProduct bookingWithProduct;

  const _BookingCard({required this.bookingWithProduct});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/bookings/${bookingWithProduct.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusBadge(context),
                  Text(
                    DateFormat('dd MMM yyyy')
                        .format(bookingWithProduct.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Product Info Row
              Row(
                children: [
                  // Product Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: AppColors.backgroundGrey,
                      child: bookingWithProduct.productImageUrl != null &&
                              bookingWithProduct.productImageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: bookingWithProduct.productImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.camera_alt,
                                size: 32,
                                color: AppColors.textTertiary,
                              ),
                            )
                          : Icon(
                              Icons.camera_alt,
                              size: 32,
                              color: AppColors.textTertiary,
                            ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Product Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bookingWithProduct.productName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getCategoryColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            bookingWithProduct.productCategory.value,
                            style: TextStyle(
                              color: _getCategoryColor(),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          bookingWithProduct.formattedTotalPrice,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Booking Details
              Row(
                children: [
                  Expanded(
                    child: _buildInfoColumn(
                      context,
                      'Start Date',
                      DateFormat('dd MMM yyyy')
                          .format(bookingWithProduct.startDate),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoColumn(
                      context,
                      'End Date',
                      DateFormat('dd MMM yyyy')
                          .format(bookingWithProduct.endDate),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoColumn(
                      context,
                      'Duration',
                      '${bookingWithProduct.numberOfDays} days',
                    ),
                  ),
                ],
              ),

              // Payment Proof Section
              if (bookingWithProduct.status == BookingStatus.pending) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                if (bookingWithProduct.paymentProofUrl != null) ...[
                  // Payment proof uploaded
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: AppColors.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Payment proof uploaded',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showPaymentProofImage(
                          context,
                          bookingWithProduct.paymentProofUrl!,
                        ),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('View'),
                      ),
                    ],
                  ),
                ] else ...[
                  // Upload payment proof button
                  _UploadPaymentProofButton(
                      bookingWithProduct: bookingWithProduct),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final status = bookingWithProduct.status;
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case BookingStatus.pending:
        bgColor = AppColors.statusPending;
        textColor = Colors.white;
        icon = Icons.schedule;
        break;
      case BookingStatus.confirmed:
        bgColor = AppColors.statusConfirmed;
        textColor = Colors.white;
        icon = Icons.check_circle;
        break;
      case BookingStatus.active:
        bgColor = AppColors.statusActive;
        textColor = Colors.white;
        icon = Icons.play_circle;
        break;
      case BookingStatus.completed:
        bgColor = AppColors.statusCompleted;
        textColor = Colors.white;
        icon = Icons.done_all;
        break;
      case BookingStatus.cancelled:
        bgColor = AppColors.statusCancelled;
        textColor = Colors.white;
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 6),
          Text(
            bookingWithProduct.statusText,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
        ),
      ],
    );
  }

  Color _getCategoryColor() {
    switch (bookingWithProduct.productCategory) {
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

  void _showPaymentProofImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Payment Proof'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadPaymentProofButton extends ConsumerStatefulWidget {
  final BookingWithProduct bookingWithProduct;

  const _UploadPaymentProofButton({required this.bookingWithProduct});

  @override
  ConsumerState<_UploadPaymentProofButton> createState() =>
      _UploadPaymentProofButtonState();
}

class _UploadPaymentProofButtonState
    extends ConsumerState<_UploadPaymentProofButton> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isUploading ? null : _pickAndUploadImage,
        icon: _isUploading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : const Icon(Icons.upload_file),
        label: Text(_isUploading ? 'Uploading...' : 'Upload Payment Proof'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    try {
      // Pick image
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      // Upload to Supabase
      final imageFile = File(image.path);
      final booking = await ref
          .read(paymentProofNotifierProvider.notifier)
          .uploadPaymentProof(
            bookingId: widget.bookingWithProduct.id,
            imageFile: imageFile,
          );

      if (booking != null && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Payment proof uploaded successfully!'),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Refresh the bookings list
        ref.invalidate(userBookingsWithProductsProvider);
      } else {
        throw Exception('Failed to upload payment proof');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Error: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
}
