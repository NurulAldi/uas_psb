import 'package:rentlens/core/config/supabase_config.dart';
import 'package:rentlens/features/payment/domain/models/payment.dart';

/// Payment Repository
/// Handles all data operations related to payments
class PaymentRepository {
  final _supabase = SupabaseConfig.client;

  /// Create a new payment record
  Future<Payment> createPayment({
    required String bookingId,
    required String orderId,
    required int amount,
    required PaymentMethod method,
    String? snapToken,
    String? snapUrl,
  }) async {
    try {
      print('💳 PAYMENT REPOSITORY: Creating payment...');
      print('   Booking ID: $bookingId');
      print('   Order ID: $orderId');
      print('   Amount: $amount');
      print('   Method: ${method.value}');

      // Get current user ID for context
      final currentUserId = await SupabaseConfig.currentUserId;
      if (currentUserId == null) {
        throw Exception('No authenticated user');
      }

      // Set user context for RLS policies
      await _supabase
          .rpc('set_user_context', params: {'user_id': currentUserId});

      final paymentData = {
        'booking_id': bookingId,
        'order_id': orderId,
        'amount': amount,
        'status': PaymentStatus.pending.value,
        'method': method.value,
        'snap_token': snapToken,
        'snap_url': snapUrl,
      };

      final response = await _supabase
          .from('payments')
          .insert(paymentData)
          .select()
          .single();

      print('✅ PAYMENT REPOSITORY: Payment created successfully');

      return Payment.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ PAYMENT REPOSITORY: Error creating payment');
      print('   Error: $e');
      print('   Stack: $stackTrace');
      rethrow;
    }
  }

  /// Get payment by booking ID
  Future<Payment?> getPaymentByBookingId(String bookingId) async {
    try {
      print('💳 PAYMENT REPOSITORY: Fetching payment for booking: $bookingId');

      final response = await _supabase
          .from('payments')
          .select()
          .eq('booking_id', bookingId)
          .maybeSingle();

      if (response == null) {
        print('💳 PAYMENT REPOSITORY: No payment found');
        return null;
      }

      print('✅ PAYMENT REPOSITORY: Payment found');
      return Payment.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ PAYMENT REPOSITORY: Error fetching payment');
      print('   Error: $e');
      print('   Stack: $stackTrace');
      return null;
    }
  }

  /// Get payment by order ID
  Future<Payment?> getPaymentByOrderId(String orderId) async {
    try {
      print('💳 PAYMENT REPOSITORY: Fetching payment for order: $orderId');

      final response = await _supabase
          .from('payments')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();

      if (response == null) {
        print('💳 PAYMENT REPOSITORY: No payment found');
        return null;
      }

      print('✅ PAYMENT REPOSITORY: Payment found');
      return Payment.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ PAYMENT REPOSITORY: Error fetching payment');
      print('   Error: $e');
      print('   Stack: $stackTrace');
      return null;
    }
  }

  /// Update payment status
  Future<Payment> updatePaymentStatus({
    required String paymentId,
    required PaymentStatus status,
    String? transactionId,
    String? fraudStatus,
    DateTime? paidAt,
  }) async {
    try {
      print('💳 PAYMENT REPOSITORY: Updating payment status...');
      print('   Payment ID: $paymentId');
      print('   New Status: ${status.value}');

      final updateData = {
        'status': status.value,
        if (transactionId != null) 'transaction_id': transactionId,
        if (fraudStatus != null) 'fraud_status': fraudStatus,
        if (paidAt != null) 'paid_at': paidAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('payments')
          .update(updateData)
          .eq('id', paymentId)
          .select()
          .single();

      print('✅ PAYMENT REPOSITORY: Payment status updated');

      return Payment.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ PAYMENT REPOSITORY: Error updating payment status');
      print('   Error: $e');
      print('   Stack: $stackTrace');
      rethrow;
    }
  }

  /// Update payment with Midtrans response
  Future<Payment> updatePaymentWithMidtransResponse({
    required String orderId,
    required Map<String, dynamic> midtransData,
  }) async {
    try {
      print('💳 ========== PAYMENT REPOSITORY UPDATE ==========');
      print('   Order ID: $orderId');
      print('   Midtrans Data: $midtransData');

      final transactionStatus = midtransData['transaction_status'] as String?;
      final fraudStatus = midtransData['fraud_status'] as String?;

      print('   Transaction Status: $transactionStatus');
      print('   Fraud Status: $fraudStatus');

      PaymentStatus status;
      if (transactionStatus == 'capture' || transactionStatus == 'settlement') {
        status = PaymentStatus.paid;
      } else if (transactionStatus == 'pending') {
        status = PaymentStatus.pending;
      } else if (transactionStatus == 'deny' ||
          transactionStatus == 'cancel' ||
          transactionStatus == 'expire') {
        status = PaymentStatus.failed;
      } else {
        status = PaymentStatus.processing;
      }

      print('   Determined Status: ${status.value}');

      final updateData = {
        'status': status.value,
        'transaction_id': midtransData['transaction_id'],
        'fraud_status': fraudStatus,
        if (status == PaymentStatus.paid)
          'paid_at': midtransData['settlement_time'] ??
              DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('   Update Data: $updateData');
      print('   Executing UPDATE query...');

      final response = await _supabase
          .from('payments')
          .update(updateData)
          .eq('order_id', orderId)
          .select()
          .single();

      print('✅ Payment updated in database');
      print('   Response: $response');
      print('✅ ========================================');

      return Payment.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ ========== PAYMENT UPDATE FAILED ==========');
      print('   Order ID: $orderId');
      print('   Error: $e');
      print('   Stack: $stackTrace');
      print('❌ ========================================');
      rethrow;
    }
  }

  /// Get all payments for a user
  Future<List<Payment>> getUserPayments(String userId) async {
    try {
      print('💳 PAYMENT REPOSITORY: Fetching payments for user: $userId');

      // Set user context for RLS policies
      await _supabase.rpc('set_user_context', params: {'user_id': userId});

      final response = await _supabase
          .from('payments')
          .select('*, bookings!inner(user_id)')
          .eq('bookings.user_id', userId)
          .order('created_at', ascending: false);

      print('✅ PAYMENT REPOSITORY: Found ${response.length} payments');

      return (response as List)
          .map((json) => Payment.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      print('❌ PAYMENT REPOSITORY: Error fetching user payments');
      print('   Error: $e');
      print('   Stack: $stackTrace');
      rethrow;
    }
  }

  /// Delete payment (for testing/cleanup)
  Future<void> deletePayment(String paymentId) async {
    try {
      print('💳 PAYMENT REPOSITORY: Deleting payment: $paymentId');

      await _supabase.from('payments').delete().eq('id', paymentId);

      print('✅ PAYMENT REPOSITORY: Payment deleted');
    } catch (e, stackTrace) {
      print('❌ PAYMENT REPOSITORY: Error deleting payment');
      print('   Error: $e');
      print('   Stack: $stackTrace');
      rethrow;
    }
  }
}
