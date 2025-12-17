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
                    'Booking tidak ditemukan',
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
                  _buildPaymentStatus(booking),
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
              'Informasi Booking',
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
              label: 'Durasi',
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
              'Informasi Pengiriman',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: booking.deliveryMethod == DeliveryMethod.delivery
                  ? Icons.local_shipping
                  : Icons.directions_walk,
              label: 'Metode',
              value: booking.deliveryMethod.label,
            ),
            if (booking.deliveryMethod == DeliveryMethod.delivery) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.place,
                label: 'Jarak',
                value: booking.distanceKm != null
                    ? '${booking.distanceKm!.toStringAsFixed(1)} km'
                    : 'Tidak ada',
              ),
              if (booking.renterAddress != null) ...[
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.home,
                  label: 'Alamat Pengiriman',
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
                  'Catatan',
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
              'Rincian Harga',
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
                    'Biaya Pengiriman',
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

    // Check if current user is the owner
    final isOwner = currentUser != null && booking.ownerId == currentUser.id;

    // OWNER ACTION BUTTONS
    if (isOwner) {
      return _buildOwnerActionButtons(context, ref, booking);
    }

    // RENTER ACTION BUTTONS
    return _buildRenterActionButtons(context, ref, booking);
  }

  /// Owner-specific action buttons
  Widget _buildOwnerActionButtons(
      BuildContext context, WidgetRef ref, BookingWithProduct booking) {
    // Pending: Show Confirm/Reject buttons (only if paid)
    if (booking.status == BookingStatus.pending) {
      // Use booking payment status instead of querying payments table again
      // This ensures consistency with owner booking management screen
      final isPaid = booking.isPaymentCompleted;

      if (!isPaid) {
        // Show info that payment is pending
        return Card(
          elevation: 2,
          color: Colors.orange[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.orange[300]!, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.pending, color: Colors.orange[700], size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '⏳ Menunggu pembayaran dari peminjam',
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Payment completed, show confirm/reject buttons
      return Column(
        children: [
          // Payment status indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  '✓ Pembayaran Diterima',
                  style: TextStyle(
                    color: Colors.green[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleRejectBooking(context, ref, booking),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Tolak'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _handleConfirmBooking(context, ref, booking),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Terima Booking'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Confirmed: Show Start Rental button
    if (booking.status == BookingStatus.confirmed) {
      return Column(
        children: [
          Card(
            elevation: 2,
            color: Colors.blue[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue[300]!, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Booking telah dikonfirmasi. Aktifkan saat barang diserahkan.',
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handleStartRental(context, ref, booking),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Mulai Rental'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      );
    }

    // Active: Show Mark as Completed button
    if (booking.status == BookingStatus.active) {
      return Column(
        children: [
          Card(
            elevation: 2,
            color: Colors.green[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.green[300]!, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.green[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rental sedang berlangsung. Tandai selesai saat barang dikembalikan.',
                      style: TextStyle(
                        color: Colors.green[900],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handleCompleteRental(context, ref, booking),
              icon: const Icon(Icons.done_all),
              label: const Text('Tandai Selesai'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      );
    }

    // For completed or cancelled, no action buttons
    return const SizedBox.shrink();
  }

  /// Renter-specific action buttons
  Widget _buildRenterActionButtons(
      BuildContext context, WidgetRef ref, BookingWithProduct booking) {
    // If confirmed, show waiting for activation info
    if (booking.status == BookingStatus.confirmed) {
      return Card(
        elevation: 2,
        color: Colors.blue[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blue[300]!, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.hourglass_bottom,
                      color: Colors.blue[700], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menunggu Pengaktifan',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pesanan telah dikonfirmasi oleh pemilik. Silakan tunggu pemilik mengaktifkan rental Anda.',
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pemilik akan mengaktifkan rental saat Anda mengambil/menerima barang',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
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

    // If pending, show payment and cancel buttons (only for renter)
    if (booking.status == BookingStatus.pending) {
      // Use booking payment status for consistency
      final isPaid = booking.isPaymentCompleted;

      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isPaid
                  ? null
                  : () async {
                      final result = await context.push<Map<String, dynamic>>(
                        '/payment/${booking.id}',
                      );
                      if (result?['paymentCompleted'] == true) {
                        // Refresh booking data
                        ref.invalidate(bookingWithProductProvider(booking.id));
                      }
                    },
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
        ],
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
            Text('Batalkan Booking?'),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan booking ini? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Batalkan'),
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
              content: Text('Booking berhasil dibatalkan'),
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

  Future<void> _handleConfirmBooking(
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
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Text('Terima Booking?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Konfirmasi booking dari ${booking.userName} untuk ${booking.product.name}?',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pembayaran sudah diterima',
                      style: TextStyle(
                        color: Colors.green[900],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Terima'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = BookingRepository();
        await repository.updateBookingStatus(
          bookingId: booking.id,
          status: BookingStatus.confirmed,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Booking diterima!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(bookingWithProductProvider(booking.id));
        }
      } catch (e) {
        if (context.mounted) {
          final errorMessage = e.toString().replaceFirst('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(errorMessage)),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleRejectBooking(
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
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 12),
            Text('Tolak Booking?'),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menolak booking dari ${booking.userName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = BookingRepository();
        await repository.updateBookingStatus(
          bookingId: booking.id,
          status: BookingStatus.cancelled,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking ditolak'),
              backgroundColor: Colors.orange,
            ),
          );
          ref.invalidate(bookingWithProductProvider(booking.id));
          context.go('/owner/bookings');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Kesalahan: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleStartRental(
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
            Icon(Icons.play_arrow, color: Colors.blue),
            SizedBox(width: 12),
            Text('Mulai Rental?'),
          ],
        ),
        content: Text(
          'Tandai booking ini sebagai aktif? Artinya ${booking.userName} telah menerima ${booking.product.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mulai'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = BookingRepository();
        await repository.updateBookingStatus(
          bookingId: booking.id,
          status: BookingStatus.active,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rental dimulai!'),
              backgroundColor: Colors.blue,
            ),
          );
          ref.invalidate(bookingWithProductProvider(booking.id));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Kesalahan: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleCompleteRental(
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
            Icon(Icons.done_all, color: Colors.green),
            SizedBox(width: 12),
            Text('Selesaikan Rental?'),
          ],
        ),
        content: Text(
          'Tandai rental ini sebagai selesai? ${booking.product.name} telah dikembalikan oleh ${booking.userName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final repository = BookingRepository();
        await repository.updateBookingStatus(
          bookingId: booking.id,
          status: BookingStatus.completed,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rental selesai!'),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(bookingWithProductProvider(booking.id));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Kesalahan: $e'), backgroundColor: Colors.red),
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

  Widget _buildPaymentStatus(BookingWithProduct booking) {
    // Use booking payment status for consistency
    final isPaid = booking.isPaymentCompleted;

    if (!isPaid) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    // Payment completed
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600]),
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
                    'Pembayaran Diterima',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
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
