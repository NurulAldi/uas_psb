import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/core/services/midtrans_service.dart';
import 'package:rentlens/features/payment/data/repositories/payment_repository.dart';
import 'package:rentlens/features/payment/domain/models/payment.dart';
import 'package:rentlens/features/booking/data/repositories/booking_repository.dart';
import 'package:rentlens/features/booking/domain/models/booking.dart';
import 'dart:async';

/// Payment Screen
/// Displays QRIS payment with clean UI/UX
/// Simulates payment completion on QR download (sandbox mode)
class PaymentScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const PaymentScreen({
    super.key,
    required this.bookingId,
  });

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final _midtransService = MidtransService();
  final _paymentRepository = PaymentRepository();
  final _bookingRepository = BookingRepository();

  Payment? _payment;
  Booking? _booking;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _paymentExpiry;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  /// Initialize payment process
  Future<void> _initializePayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get booking details
      final booking = await _bookingRepository.getBookingById(widget.bookingId);
      if (booking == null) {
        throw Exception('Booking not found');
      }

      setState(() => _booking = booking);

      // Check if payment already exists
      var payment =
          await _paymentRepository.getPaymentByBookingId(widget.bookingId);

      // If no payment, create new one
      if (payment == null) {
        payment = await _createNewPayment(booking);
      }

      setState(() {
        _payment = payment;
        _paymentExpiry = payment?.createdAt.add(const Duration(hours: 24));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Create new payment transaction
  Future<Payment> _createNewPayment(Booking booking) async {
    try {
      final orderId =
          'RENT-${booking.id.substring(0, 8)}-${DateTime.now().millisecondsSinceEpoch}';
      final amount = booking.totalPrice.toInt();

      print('💳 Creating payment for booking: ${booking.id}');
      print('   Order ID: $orderId');
      print('   Amount: Rp $amount');

      // Create Midtrans transaction
      final midtransResponse = await _midtransService.createTransaction(
        orderId: orderId,
        grossAmount: amount,
        customerName: 'User',
        customerEmail: 'user@example.com',
        customerPhone: '08123456789',
        itemDetails: [
          {
            'id': booking.productId,
            'name': 'Product Rental',
            'price': amount,
            'quantity': 1,
          }
        ],
      );

      if (!midtransResponse['success']) {
        throw Exception(midtransResponse['error']);
      }

      // Save payment to database
      final payment = await _paymentRepository.createPayment(
        bookingId: booking.id,
        orderId: orderId,
        amount: amount,
        method: PaymentMethod.qris,
        snapToken: midtransResponse['token'],
        snapUrl: midtransResponse['redirect_url'],
      );

      print('✅ Payment created successfully');
      return payment;
    } catch (e) {
      print('❌ Error creating payment: $e');
      rethrow;
    }
  }

  /// Simulate payment completion (sandbox mode)
  Future<void> _handleDownloadQR() async {
    if (_payment == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing payment...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Simulate payment processing delay
      await Future.delayed(const Duration(seconds: 2));

      // In sandbox mode, simulate successful payment
      // In production, this would check actual transaction status
      final mockMidtransData = {
        'transaction_status': 'settlement',
        'payment_type': 'qris',
        'transaction_time': DateTime.now().toIso8601String(),
      };

      await _paymentRepository.updatePaymentWithMidtransResponse(
        orderId: _payment!.orderId,
        midtransData: mockMidtransData,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show success dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
        content: const Text(
          'Your payment has been confirmed.\nYou can now proceed with your booking.',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/bookings/${widget.bookingId}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('View Booking'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Preparing payment...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_payment == null || _booking == null) {
      return const Center(child: Text('Payment not found'));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPaymentHeader(),
          _buildQRCodeSection(),
          _buildPaymentInfo(),
          _buildInstructions(),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildPaymentHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.qr_code_scanner,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          const Text(
            'Scan QR Code to Pay',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total Amount',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _payment!.formattedAmount,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: _payment!.orderId,
              version: QrVersions.auto,
              size: 250,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusBadge(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pending_outlined, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Text(
            'Waiting for Payment',
            style: TextStyle(
              color: Colors.orange[900],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfo() {
    if (_paymentExpiry == null) return const SizedBox();

    final remainingTime = _paymentExpiry!.difference(DateTime.now());
    final hours = remainingTime.inHours;
    final minutes = remainingTime.inMinutes % 60;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Payment Expires In:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              Text(
                '${hours}h ${minutes}m',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.receipt_long,
            label: 'Order ID',
            value: _payment!.orderId.substring(0, 20) + '...',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.payment,
            label: 'Payment Method',
            value: 'QRIS',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'How to Pay',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionStep(1, 'Open your e-wallet app (GoPay, OVO, DANA, etc.)'),
          _buildInstructionStep(2, 'Scan the QR code above'),
          _buildInstructionStep(3, 'Confirm payment in your app'),
          _buildInstructionStep(4, 'Wait for payment confirmation'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.science_outlined, color: Colors.amber[800], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sandbox Mode: Click "Download QR" to simulate payment',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleDownloadQR,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.download, size: 20),
              label: const Text(
                'Download QR Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel Payment',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              'Payment Error',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializePayment,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
    Color textColor;

    switch (status) {
      case PaymentStatus.pending:
      case PaymentStatus.processing:
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
        break;
      case PaymentStatus.paid:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        break;
      default:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
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
        ),
      ),
    );
  }

  Widget _buildPaymentWebView() {
    if (_payment?.snapUrl == null) {
      return const Center(child: Text('No payment URL available'));
    }

    // Initialize WebView
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('📱 WebView loading: $url');
          },
          onPageFinished: (String url) {
            print('✅ WebView loaded: $url');
            // Check if payment completed
            if (url.contains('status_code=200') ||
                url.contains('transaction_status=settlement')) {
              _checkPaymentStatus();
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(_payment!.snapUrl!));

    return WebViewWidget(controller: _webViewController!);
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openInBrowser(),
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('Open in Browser'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _checkPaymentStatus,
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Check Status'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              'Payment Error',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializePayment,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Open payment URL in external browser
  Future<void> _openInBrowser() async {
    if (_payment?.snapUrl == null) return;

    final url = Uri.parse(_payment!.snapUrl!);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open payment URL')),
        );
      }
    }
  }
}
