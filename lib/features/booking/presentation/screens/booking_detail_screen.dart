import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/features/booking/data/repositories/booking_repository.dart';
import 'package:rentlens/features/booking/domain/models/booking.dart';
import 'package:rentlens/features/booking/domain/models/booking_with_product.dart';
import 'package:rentlens/features/payment/data/repositories/payment_repository.dart';
import 'package:rentlens/features/payment/domain/models/payment.dart';
import 'package:rentlens/features/auth/providers/auth_provider.dart';

/// Provider for booking with product details
final bookingWithProductProvider = FutureProvider.autoDispose
    .family<BookingWithProduct?, String>((ref, bookingId) async {
  final repository = BookingRepository();
  return await repository.getBookingWithProductById(bookingId);
});

/// Provider for payment status by booking ID
final paymentByBookingProvider =
    FutureProvider.autoDispose.family<Payment?, String>((ref, bookingId) async {
  final repository = PaymentRepository();
  return await repository.getPaymentByBookingId(bookingId);
});

class BookingDetailScreen extends ConsumerWidget {
  final String bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingWithProductProvider(bookingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/bookings');
            }
          },
        ),
      ),
      body: bookingAsync.when(
        data: (booking) {
          if (booking == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Booking not found',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(bookingWithProductProvider(bookingId));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductCard(booking),
                  const SizedBox(height: 24),
                  _buildStatusTimeline(booking.status),
                  const SizedBox(height: 24),
                  _buildBookingInfo(booking),
                  const SizedBox(height: 24),
                  _buildPaymentStatus(ref, booking.id),
                  const SizedBox(height: 24),
                  _buildDeliveryInfo(booking),
                  if (booking.notes != null) ...[
                    const SizedBox(height: 24),
                    _buildNotesSection(booking.notes!),
                  ],
                  const SizedBox(height: 24),
                  _buildPriceBreakdown(booking),
                  const SizedBox(height: 24),
                  _buildActionButtons(context, ref, booking),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Kesalahan: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(bookingWithProductProvider(bookingId)),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(BookingWithProduct booking) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: booking.productImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: booking.productImageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.camera_alt, size: 30),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.camera_alt, size: 30),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.productName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.productCategory.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(BookingStatus status) {
    final statuses = [
      BookingStatus.pending,
      BookingStatus.confirmed,
      BookingStatus.active,
      BookingStatus.completed,
    ];

    final currentIndex = statuses.indexOf(status);
    final isCancelled = status == BookingStatus.cancelled;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Status: ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                _buildStatusBadge(status),
              ],
            ),
            if (!isCancelled) ...[
              const SizedBox(height: 20),
              Row(
                children: List.generate(statuses.length * 2 - 1, (index) {
                  if (index.isEven) {
                    // Status circle
                    final statusIndex = index ~/ 2;
                    final isActive = statusIndex <= currentIndex;
                    return _buildStatusCircle(
                      statuses[statusIndex].label,
                      isActive,
                    );
                  } else {
                    // Connecting line
                    final statusIndex = (index - 1) ~/ 2;
                    final isActive = statusIndex < currentIndex;
                    return Expanded(
                      child: Container(
                        height: 2,
                        color: isActive ? AppColors.primary : Colors.grey[300],
                      ),
                    );
                  }
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCircle(String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.primary : Colors.grey[300],
          ),
          child: Icon(
            isActive ? Icons.check : Icons.circle,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? AppColors.primary : Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BookingStatus status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case BookingStatus.pending:
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
        break;
      case BookingStatus.confirmed:
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[900]!;
        break;
      case BookingStatus.active:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        break;
      case BookingStatus.completed:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[800]!;
        break;
      case BookingStatus.cancelled:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBookingInfo(BookingWithProduct booking) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Booking Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Tanggal Mulai',
              value: _formatDate(booking.startDate),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.event,
              label: 'Tanggal Selesai',
              value: _formatDate(booking.endDate),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.timer_outlined,
              label: 'Duration',
              value: '${booking.numberOfDays} hari',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfo(BookingWithProduct booking) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: booking.deliveryMethod == DeliveryMethod.delivery
                  ? Icons.local_shipping
                  : Icons.directions_walk,
              label: 'Method',
              value: booking.deliveryMethod.label,
            ),
            if (booking.deliveryMethod == DeliveryMethod.delivery) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.place,
                label: 'Distance',
                value: booking.distanceKm != null
                    ? '${booking.distanceKm!.toStringAsFixed(1)} km'
                    : 'N/A',
              ),
              if (booking.renterAddress != null) ...[
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.home,
                  label: 'Delivery Address',
                  value: booking.renterAddress!,
                  valueMaxLines: 3,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(String notes) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notes, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 8),
                const Text(
                  'Notes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              notes,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceBreakdown(BookingWithProduct booking) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Price Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sewa Produk (${booking.numberOfDays} hari)',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                Text(
                  _formatPrice(booking.productSubtotal),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (booking.deliveryMethod == DeliveryMethod.delivery) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Delivery Fee',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  Text(
                    booking.formattedDeliveryFee,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  booking.formattedTotalPrice,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, BookingWithProduct booking) {
    // Get current user
    final currentUser = ref.watch(currentUserProvider);

    // If current user is the owner, don't show action buttons
    if (currentUser != null && booking.product.ownerId == currentUser.id) {
      return const SizedBox.shrink();
    }

    // If pending, show payment and cancel buttons (only for renter)
    if (booking.status == BookingStatus.pending) {
      final paymentAsync = ref.watch(paymentByBookingProvider(booking.id));

      return paymentAsync.when(
        data: (payment) {
          final isPaid = payment?.status == PaymentStatus.paid;

          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isPaid
                      ? null
                      : () => context.push('/payment/${booking.id}'),
                  icon: Icon(isPaid ? Icons.check_circle : Icons.payment),
                  label: Text(isPaid ? 'Pembayaran Selesai' : 'Bayar Sekarang'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: isPaid ? Colors.green : null,
                  ),
                ),
              ),
              if (!isPaid) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _handleCancelBooking(context, ref, booking),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Batalkan Pesanan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/payment/${booking.id}'),
                icon: const Icon(Icons.payment),
                label: const Text('Bayar Sekarang'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _handleCancelBooking(context, ref, booking),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Batalkan Pesanan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // For other statuses, no action buttons
    return const SizedBox.shrink();
  }

  Future<void> _handleCancelBooking(
    BuildContext context,
    WidgetRef ref,
    BookingWithProduct booking,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Cancel Booking?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = BookingRepository();
        await repository.cancelBooking(booking.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking cancelled successfully'),
              backgroundColor: Colors.orange,
            ),
          );
          ref.invalidate(bookingWithProductProvider(booking.id));
          // Navigate back to My Bookings list
          context.go('/bookings');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kesalahan: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatPrice(double price) {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  Widget _buildPaymentStatus(WidgetRef ref, String bookingId) {
    final paymentAsync = ref.watch(paymentByBookingProvider(bookingId));

    return paymentAsync.when(
      data: (payment) {
        if (payment == null) {
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.payment, color: Colors.grey[400]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status Pembayaran',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Belum ada catatan pembayaran',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Determine status color
        Color statusColor;
        IconData statusIcon;
        switch (payment.status) {
          case PaymentStatus.paid:
            statusColor = Colors.green;
            statusIcon = Icons.check_circle;
            break;
          case PaymentStatus.pending:
            statusColor = Colors.orange;
            statusIcon = Icons.pending;
            break;
          case PaymentStatus.processing:
            statusColor = Colors.blue;
            statusIcon = Icons.hourglass_empty;
            break;
          case PaymentStatus.failed:
            statusColor = Colors.red;
            statusIcon = Icons.error;
            break;
          case PaymentStatus.expired:
            statusColor = Colors.grey;
            statusIcon = Icons.schedule;
            break;
          case PaymentStatus.cancelled:
            statusColor = Colors.grey;
            statusIcon = Icons.cancel;
            break;
        }

        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.payment, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Payment Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPaymentInfoRow(
                  'Order ID',
                  payment.orderId.length > 30
                      ? '${payment.orderId.substring(0, 30)}...'
                      : payment.orderId,
                ),
                const SizedBox(height: 8),
                _buildPaymentInfoRow(
                  'Amount',
                  payment.formattedAmount,
                ),
                const SizedBox(height: 8),
                _buildPaymentInfoRow(
                  'Method',
                  payment.method.label,
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Status: ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            payment.status.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (payment.paidAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Paid at: ${_formatDate(payment.paidAt!)} ${payment.paidAt!.hour.toString().padLeft(2, '0')}:${payment.paidAt!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading payment status...'),
            ],
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPaymentInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int valueMaxLines;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueMaxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: valueMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
