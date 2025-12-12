import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/features/booking/data/repositories/booking_repository.dart';
import 'package:rentlens/features/booking/domain/models/booking_with_product.dart';
import 'package:rentlens/features/booking/domain/models/booking.dart';
import 'package:rentlens/features/auth/providers/profile_provider.dart';
import 'package:rentlens/features/payment/data/repositories/payment_repository.dart';
import 'package:rentlens/features/payment/domain/models/payment.dart';

/// Provider for owner bookings
final ownerBookingsProvider =
    FutureProvider.autoDispose<List<BookingWithProduct>>((ref) async {
  final profile = await ref.watch(currentUserProfileProvider.future);
  if (profile == null) return [];

  final repository = BookingRepository();
  return await repository.getOwnerBookings(profile.id);
});

/// Owner Booking Management Screen
/// Features:
/// - View all bookings for products owned by user
/// - Filter by status (pending, confirmed, active, completed)
/// - Confirm/reject pending bookings
/// - Start rental (pending → confirmed → active)
/// - Complete rental (active → completed)
/// - View delivery details
class OwnerBookingManagementScreen extends ConsumerStatefulWidget {
  const OwnerBookingManagementScreen({super.key});

  @override
  ConsumerState<OwnerBookingManagementScreen> createState() =>
      _OwnerBookingManagementScreenState();
}

class _OwnerBookingManagementScreenState
    extends ConsumerState<OwnerBookingManagementScreen> {
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(ownerBookingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Requests'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(ownerBookingsProvider),
            tooltip: 'Muat Ulang',
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
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
                Icon(Icons.filter_list, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Filter:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedStatus,
                        isExpanded: true,
                        icon: Icon(Icons.arrow_drop_down,
                            color: AppColors.primary),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        },
                        items: [
                          DropdownMenuItem(
                              value: null, child: Text('Semua Status')),
                          DropdownMenuItem(
                              value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(
                              value: 'confirmed', child: Text('Confirmed')),
                          DropdownMenuItem(
                              value: 'active', child: Text('Active')),
                          DropdownMenuItem(
                              value: 'completed', child: Text('Completed')),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Booking List
          Expanded(
            child: bookingsAsync.when(
              data: (bookings) {
                // Filter bookings
                final filteredBookings = _selectedStatus == null
                    ? bookings
                    : bookings
                        .where((b) => b.status.value == _selectedStatus)
                        .toList();

                if (filteredBookings.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ownerBookingsProvider);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredBookings.length,
                    itemBuilder: (context, index) {
                      return _buildBookingCard(filteredBookings[index]);
                    },
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
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(ownerBookingsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({String? status}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            status == null ? 'No bookings yet' : 'No ${status} bookings',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bookings will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(BookingWithProduct booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => context.push('/bookings/${booking.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Status & Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildStatusBadge(booking.status),
                      const SizedBox(width: 8),
                      _buildPaymentStatusBadge(booking.id),
                    ],
                  ),
                  Text(
                    _formatDate(booking.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Product Info
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: booking.product.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: booking.product.imageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.camera_alt, size: 30),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: const Icon(Icons.camera_alt, size: 30),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Renter: ${booking.userName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Rental Period & Price
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.calendar_today,
                      '${_formatDate(booking.startDate)} - ${_formatDate(booking.endDate)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoItem(
                    Icons.timer_outlined,
                    '${booking.numberOfDays} day${booking.numberOfDays > 1 ? 's' : ''}',
                  ),
                  _buildInfoItem(
                    booking.deliveryMethod == DeliveryMethod.delivery
                        ? Icons.local_shipping
                        : Icons.directions_walk,
                    booking.deliveryMethod.label,
                  ),
                ],
              ),

              if (booking.deliveryMethod == DeliveryMethod.delivery &&
                  booking.distanceKm != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place, size: 14, color: Colors.orange[800]),
                      const SizedBox(width: 4),
                      Text(
                        '${booking.distanceKm!.toStringAsFixed(1)} km • Delivery fee: ${booking.formattedDeliveryFee}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Total Price
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      booking.formattedTotalPrice,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // ✨ NEW: Payment Status Badge
              if (booking.status == BookingStatus.pending) ...[
                const SizedBox(height: 12),
                _buildPaymentStatusInfo(booking),
              ],

              // Action Buttons
              if (booking.status == BookingStatus.pending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleReject(booking),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        // ✨ UPDATED: Only enabled if payment is completed
                        onPressed: booking.canBeConfirmedByOwner
                            ? () => _handleConfirm(booking)
                            : null,
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(
                          booking.isPaymentCompleted
                              ? 'Accept'
                              : 'Menunggu Pembayaran',
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (booking.status == BookingStatus.confirmed) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleStartRental(booking),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start Rental'),
                  ),
                ),
              ] else if (booking.status == BookingStatus.active) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleCompleteRental(booking),
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Mark as Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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

  /// ✨ NEW: Build payment status info widget
  Widget _buildPaymentStatusInfo(BookingWithProduct booking) {
    Color backgroundColor;
    Color textColor;
    Color borderColor;
    IconData icon;
    String title;
    String subtitle;

    if (booking.isPaymentCompleted) {
      backgroundColor = Colors.green[50]!;
      textColor = Colors.green[900]!;
      borderColor = Colors.green[300]!;
      icon = Icons.check_circle;
      title = '✓ Pembayaran Diterima';
      subtitle = 'Anda dapat menerima booking ini';
    } else {
      backgroundColor = Colors.orange[50]!;
      textColor = Colors.orange[900]!;
      borderColor = Colors.orange[300]!;
      icon = Icons.pending;
      title = '⏳ ${booking.paymentStatusText}';
      subtitle = 'Menunggu peminjam menyelesaikan pembayaran';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusBadge(String bookingId) {
    return FutureBuilder<Payment?>(
      future: PaymentRepository().getPaymentByBookingId(bookingId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          // No payment yet
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.payment, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Unpaid',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        final payment = snapshot.data!;
        Color badgeColor;
        Color textColor;
        IconData icon;
        String label;

        switch (payment.status) {
          case PaymentStatus.paid:
            badgeColor = Colors.green[100]!;
            textColor = Colors.green[900]!;
            icon = Icons.check_circle;
            label = 'Paid';
            break;
          case PaymentStatus.pending:
            badgeColor = Colors.orange[100]!;
            textColor = Colors.orange[900]!;
            icon = Icons.pending;
            label = 'Pending';
            break;
          case PaymentStatus.processing:
            badgeColor = Colors.blue[100]!;
            textColor = Colors.blue[900]!;
            icon = Icons.hourglass_empty;
            label = 'Processing';
            break;
          case PaymentStatus.failed:
            badgeColor = Colors.red[100]!;
            textColor = Colors.red[900]!;
            icon = Icons.error;
            label = 'Failed';
            break;
          case PaymentStatus.expired:
          case PaymentStatus.cancelled:
            badgeColor = Colors.grey[200]!;
            textColor = Colors.grey[700]!;
            icon = Icons.cancel;
            label = 'Cancelled';
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: textColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: textColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _handleConfirm(BookingWithProduct booking) async {
    // ✨ NEW: Double check payment status before showing dialog
    if (!booking.isPaymentCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tidak bisa menerima booking. ${booking.paymentStatusText}.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Text('Accept Booking?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm booking from ${booking.userName} for ${booking.product.name}?',
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = BookingRepository();
        await repository.updateBookingStatus(
          bookingId: booking.id,
          status: BookingStatus.confirmed,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Booking accepted!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(ownerBookingsProvider);
        }
      } catch (e) {
        if (mounted) {
          // ✨ UPDATED: Better error message display
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

  Future<void> _handleReject(BookingWithProduct booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 12),
            Text('Reject Booking?'),
          ],
        ),
        content: Text(
          'Are you sure you want to reject booking from ${booking.userName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = BookingRepository();
        await repository.updateBookingStatus(
          bookingId: booking.id,
          status: BookingStatus.cancelled,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Booking rejected'),
              backgroundColor: Colors.orange,
            ),
          );
          ref.invalidate(ownerBookingsProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleStartRental(BookingWithProduct booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.play_arrow, color: Colors.blue),
            SizedBox(width: 12),
            Text('Start Rental?'),
          ],
        ),
        content: Text(
          'Mark this booking as active? This means ${booking.userName} has received the ${booking.product.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = BookingRepository();
        await repository.updateBookingStatus(
          bookingId: booking.id,
          status: BookingStatus.active,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rental started!'),
              backgroundColor: Colors.blue,
            ),
          );
          ref.invalidate(ownerBookingsProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleCompleteRental(BookingWithProduct booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.done_all, color: Colors.green),
            SizedBox(width: 12),
            Text('Complete Rental?'),
          ],
        ),
        content: Text(
          'Mark this rental as completed? The ${booking.product.name} has been returned by ${booking.userName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final repository = BookingRepository();
        await repository.updateBookingStatus(
          bookingId: booking.id,
          status: BookingStatus.completed,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rental completed!'),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(ownerBookingsProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
