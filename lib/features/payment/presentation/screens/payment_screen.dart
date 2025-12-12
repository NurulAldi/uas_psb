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
import 'package:rentlens/features/booking/presentation/screens/booking_detail_screen.dart';

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

  /// Create new payment transaction with QRIS
  Future<Payment> _createNewPayment(Booking booking) async {
    try {
      final orderId =
          'RENT-${booking.id.substring(0, 8)}-${DateTime.now().millisecondsSinceEpoch}';
      final amount = booking.totalPrice.toInt();

      print('💳 Creating QRIS payment for booking: ${booking.id}');
      print('   Order ID: $orderId');
      print('   Amount: Rp $amount');

      // Charge QRIS transaction to Midtrans
      final midtransResponse = await _midtransService.chargeQris(
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

      final qrisString = midtransResponse['qris_string'] as String?;
      final transactionId = midtransResponse['transaction_id'] as String?;

      print('✅ QRIS charged successfully');
      print('   Transaction ID: $transactionId');
      print(
          '   QRIS String: ${qrisString != null ? 'Generated' : 'Not available'}');

      // Save payment to database
      final payment = await _paymentRepository.createPayment(
        bookingId: booking.id,
        orderId: orderId,
        amount: amount,
        method: PaymentMethod.qris,
        snapToken: qrisString, // Store QRIS string in snapToken field
        snapUrl: qrisString, // Also in snapUrl for compatibility
      );

      print('✅ Payment record created successfully');
      return payment;
    } catch (e) {
      print('❌ Error creating payment: $e');
      rethrow;
    }
  }

  /// Download QR Code and mark payment as successful
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
      // Simulate downloading QR and payment success
      await Future.delayed(const Duration(seconds: 2));

      print('📥 ========== PAYMENT UPDATE STARTED ==========');
      print('   Payment ID: ${_payment!.id}');
      print('   Order ID: ${_payment!.orderId}');
      print('   Booking ID: ${widget.bookingId}');
      print('   Current Status: ${_payment!.status.value}');

      // Simulate settlement response from Midtrans
      final mockSettlementData = {
        'status_code': '200',
        'status_message': 'Success, transaction is found',
        'transaction_id': _payment!.orderId,
        'order_id': _payment!.orderId,
        'gross_amount': _payment!.amount.toString(),
        'payment_type': 'qris',
        'transaction_time': DateTime.now().toIso8601String(),
        'settlement_time': DateTime.now().toIso8601String(),
        'transaction_status': 'settlement',
        'fraud_status': 'accept',
      };

      print('✅ Mock settlement data prepared');
      print('   Data: $mockSettlementData');

      // Update payment in database as settlement
      print('📝 Updating payment in database...');
      final updatedPayment =
          await _paymentRepository.updatePaymentWithMidtransResponse(
        orderId: _payment!.orderId,
        midtransData: mockSettlementData,
      );

      print('✅ Payment updated successfully!');
      print('   New Status: ${updatedPayment.status.value}');
      print('   Transaction ID: ${updatedPayment.transactionId}');
      print('   Paid At: ${updatedPayment.paidAt}');

      // Invalidate ALL payment-related providers to sync across app
      print('🔄 Invalidating providers for sync...');
      ref.invalidate(paymentByBookingProvider(widget.bookingId));
      ref.invalidate(bookingWithProductProvider(widget.bookingId));

      print('✅ ========== PAYMENT UPDATE COMPLETED ==========');

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showSuccessDialog(); // Always show success (simulated settlement)
      }
    } catch (e, stackTrace) {
      print('❌ ========== PAYMENT UPDATE FAILED ==========');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
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
            child: _payment!.snapToken != null &&
                    _payment!.snapToken!.isNotEmpty
                ? QrImageView(
                    data: _payment!.snapToken!, // Use QRIS string from Midtrans
                    version: QrVersions.auto,
                    size: 250,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code, size: 100, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'QR Code not available',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Order ID: ${_payment!.orderId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
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
          const Icon(Icons.pending_outlined, color: Colors.orange, size: 18),
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
            value: _payment!.orderId.length > 25
                ? '${_payment!.orderId.substring(0, 25)}...'
                : _payment!.orderId,
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
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
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
          _buildInstructionStep(
              1, 'Open your e-wallet app (GoPay, OVO, DANA, etc.)'),
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
                Icon(Icons.science_outlined,
                    color: Colors.amber[800], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Click "Download QR Code" to complete payment',
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
