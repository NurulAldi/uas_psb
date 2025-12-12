import 'package:flutter/material.dart';
import 'package:rentlens/features/booking/domain/models/booking.dart';
import 'package:rentlens/core/theme/app_colors.dart';

/// Widget untuk menampilkan timeline status booking
/// Memberikan visibility yang jelas kepada user tentang progress booking
class BookingStatusTimeline extends StatelessWidget {
  final BookingStatus currentStatus;
  final BookingPaymentStatus paymentStatus;
  final bool
      isOwnerView; // true = owner perspective, false = renter perspective

  const BookingStatusTimeline({
    super.key,
    required this.currentStatus,
    required this.paymentStatus,
    this.isOwnerView = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status Booking',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Column(
      children: [
        // Step 1: Booking Created
        _buildTimelineStep(
          stepNumber: 1,
          title: 'Booking Dibuat',
          subtitle: 'Permintaan booking telah dibuat',
          isCompleted: true,
          isActive: currentStatus == BookingStatus.pending &&
              paymentStatus == BookingPaymentStatus.pending,
          icon: Icons.event_note,
        ),

        _buildTimelineConnector(
          isActive: currentStatus.index >= BookingStatus.pending.index,
        ),

        // Step 2: Payment
        _buildTimelineStep(
          stepNumber: 2,
          title: 'Pembayaran',
          subtitle: _getPaymentSubtitle(),
          isCompleted: paymentStatus == BookingPaymentStatus.paid,
          isActive: currentStatus == BookingStatus.pending &&
              paymentStatus == BookingPaymentStatus.pending,
          icon: Icons.payment,
          statusBadge: _buildPaymentStatusBadge(),
        ),

        _buildTimelineConnector(
          isActive: paymentStatus == BookingPaymentStatus.paid,
        ),

        // Step 3: Owner Confirmation
        _buildTimelineStep(
          stepNumber: 3,
          title: 'Konfirmasi Pemilik',
          subtitle: _getConfirmationSubtitle(),
          isCompleted: currentStatus.index >= BookingStatus.confirmed.index,
          isActive: currentStatus == BookingStatus.pending &&
              paymentStatus == BookingPaymentStatus.paid,
          icon: Icons.verified_user,
        ),

        _buildTimelineConnector(
          isActive: currentStatus.index >= BookingStatus.confirmed.index,
        ),

        // Step 4: Rental Active
        _buildTimelineStep(
          stepNumber: 4,
          title: 'Masa Sewa',
          subtitle: currentStatus == BookingStatus.active
              ? 'Barang sedang disewa'
              : currentStatus.index > BookingStatus.active.index
                  ? 'Masa sewa selesai'
                  : 'Menunggu waktu sewa',
          isCompleted: currentStatus.index >= BookingStatus.active.index,
          isActive: currentStatus == BookingStatus.active,
          icon: Icons.schedule,
        ),

        _buildTimelineConnector(
          isActive: currentStatus == BookingStatus.completed,
        ),

        // Step 5: Completed
        _buildTimelineStep(
          stepNumber: 5,
          title: 'Selesai',
          subtitle: currentStatus == BookingStatus.completed
              ? 'Transaksi selesai'
              : 'Menunggu penyelesaian',
          isCompleted: currentStatus == BookingStatus.completed,
          isActive: currentStatus == BookingStatus.completed,
          icon: Icons.done_all,
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isActive,
    required IconData icon,
    Widget? statusBadge,
  }) {
    Color circleColor;
    Color textColor;

    if (isCompleted) {
      circleColor = Colors.green;
      textColor = Colors.green[900]!;
    } else if (isActive) {
      circleColor = AppColors.primary;
      textColor = AppColors.primary;
    } else {
      circleColor = Colors.grey[300]!;
      textColor = Colors.grey[600]!;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Circle indicator
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted || isActive ? circleColor : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: circleColor,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Icon(icon, color: textColor, size: 20),
          ),
        ),
        const SizedBox(width: 12),

        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (statusBadge != null) statusBadge,
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector({required bool isActive}) {
    return Padding(
      padding: const EdgeInsets.only(left: 19),
      child: Container(
        width: 2,
        height: 24,
        color: isActive ? AppColors.primary : Colors.grey[300],
      ),
    );
  }

  Widget _buildPaymentStatusBadge() {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (paymentStatus) {
      case BookingPaymentStatus.paid:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        label = 'LUNAS';
        break;
      case BookingPaymentStatus.pending:
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
        label = 'PENDING';
        break;
      case BookingPaymentStatus.processing:
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[900]!;
        label = 'PROSES';
        break;
      case BookingPaymentStatus.failed:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        label = 'GAGAL';
        break;
      default:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        label = paymentStatus.label.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getPaymentSubtitle() {
    switch (paymentStatus) {
      case BookingPaymentStatus.paid:
        return 'Pembayaran berhasil';
      case BookingPaymentStatus.pending:
        return isOwnerView
            ? 'Menunggu pembayaran dari penyewa'
            : 'Silakan selesaikan pembayaran';
      case BookingPaymentStatus.processing:
        return 'Sedang memproses pembayaran';
      case BookingPaymentStatus.failed:
        return 'Pembayaran gagal';
      case BookingPaymentStatus.expired:
        return 'Pembayaran kadaluarsa';
      case BookingPaymentStatus.cancelled:
        return 'Pembayaran dibatalkan';
    }
  }

  String _getConfirmationSubtitle() {
    if (currentStatus.index >= BookingStatus.confirmed.index) {
      return 'Booking telah dikonfirmasi';
    } else if (paymentStatus == BookingPaymentStatus.paid) {
      return isOwnerView
          ? 'Silakan konfirmasi booking'
          : 'Menunggu konfirmasi pemilik';
    } else {
      return 'Selesaikan pembayaran terlebih dahulu';
    }
  }
}

/// Compact version untuk digunakan di card/list
class BookingStatusTimelineCompact extends StatelessWidget {
  final BookingStatus currentStatus;
  final BookingPaymentStatus paymentStatus;

  const BookingStatusTimelineCompact({
    super.key,
    required this.currentStatus,
    required this.paymentStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getBorderColor(), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(_getIcon(), color: _getTextColor(), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusTitle(),
                  style: TextStyle(
                    color: _getTextColor(),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getStatusSubtitle(),
                  style: TextStyle(
                    color: _getTextColor().withValues(alpha: 0.8),
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

  Color _getBackgroundColor() {
    if (currentStatus == BookingStatus.cancelled) {
      return Colors.red[50]!;
    } else if (currentStatus == BookingStatus.completed) {
      return Colors.green[50]!;
    } else if (currentStatus == BookingStatus.pending &&
        paymentStatus == BookingPaymentStatus.pending) {
      return Colors.orange[50]!;
    } else {
      return Colors.blue[50]!;
    }
  }

  Color _getBorderColor() {
    if (currentStatus == BookingStatus.cancelled) {
      return Colors.red[300]!;
    } else if (currentStatus == BookingStatus.completed) {
      return Colors.green[300]!;
    } else if (currentStatus == BookingStatus.pending &&
        paymentStatus == BookingPaymentStatus.pending) {
      return Colors.orange[300]!;
    } else {
      return Colors.blue[300]!;
    }
  }

  Color _getTextColor() {
    if (currentStatus == BookingStatus.cancelled) {
      return Colors.red[900]!;
    } else if (currentStatus == BookingStatus.completed) {
      return Colors.green[900]!;
    } else if (currentStatus == BookingStatus.pending &&
        paymentStatus == BookingPaymentStatus.pending) {
      return Colors.orange[900]!;
    } else {
      return Colors.blue[900]!;
    }
  }

  IconData _getIcon() {
    if (currentStatus == BookingStatus.cancelled) {
      return Icons.cancel;
    } else if (currentStatus == BookingStatus.completed) {
      return Icons.done_all;
    } else if (currentStatus == BookingStatus.pending &&
        paymentStatus == BookingPaymentStatus.pending) {
      return Icons.pending;
    } else if (currentStatus == BookingStatus.pending &&
        paymentStatus == BookingPaymentStatus.paid) {
      return Icons.hourglass_empty;
    } else {
      return Icons.check_circle;
    }
  }

  String _getStatusTitle() {
    if (currentStatus == BookingStatus.pending) {
      if (paymentStatus == BookingPaymentStatus.pending) {
        return 'Menunggu Pembayaran';
      } else if (paymentStatus == BookingPaymentStatus.paid) {
        return 'Menunggu Konfirmasi Pemilik';
      } else {
        return 'Pembayaran ${paymentStatus.label}';
      }
    } else if (currentStatus == BookingStatus.confirmed) {
      return 'Booking Dikonfirmasi';
    } else if (currentStatus == BookingStatus.active) {
      return 'Sedang Berlangsung';
    } else if (currentStatus == BookingStatus.completed) {
      return 'Selesai';
    } else {
      return 'Dibatalkan';
    }
  }

  String _getStatusSubtitle() {
    if (currentStatus == BookingStatus.pending) {
      if (paymentStatus == BookingPaymentStatus.pending) {
        return 'Silakan selesaikan pembayaran';
      } else if (paymentStatus == BookingPaymentStatus.paid) {
        return 'Pembayaran diterima, menunggu pemilik';
      } else {
        return 'Silakan cek status pembayaran';
      }
    } else if (currentStatus == BookingStatus.confirmed) {
      return 'Siap untuk dimulai';
    } else if (currentStatus == BookingStatus.active) {
      return 'Barang sedang disewa';
    } else if (currentStatus == BookingStatus.completed) {
      return 'Transaksi berhasil diselesaikan';
    } else {
      return 'Booking dibatalkan';
    }
  }
}
