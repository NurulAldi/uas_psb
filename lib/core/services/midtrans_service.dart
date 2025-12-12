import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Midtrans Service
/// Handles all Midtrans API interactions for payment processing
/// Uses Sandbox environment for development/testing
class MidtransService {
  static final MidtransService _instance = MidtransService._internal();
  factory MidtransService() => _instance;
  MidtransService._internal();

  // Base URL for Midtrans Snap API
  final String _baseUrl = 'https://app.sandbox.midtrans.com/snap/v1';
  final String _apiBaseUrl = 'https://api.sandbox.midtrans.com/v2';

  /// Get Server Key from environment
  String get serverKey => dotenv.env['MIDTRANS_SERVER_KEY'] ?? '';

  /// Get Client Key from environment
  String get clientKey => dotenv.env['MIDTRANS_CLIENT_KEY'] ?? '';

  /// Check if production mode
  bool get isProduction => dotenv.env['MIDTRANS_IS_PRODUCTION'] == 'true';

  /// Generate basic auth header
  String get _basicAuth => 'Basic ${base64Encode(utf8.encode('$serverKey:'))}';

  /// Create transaction and get Snap token
  /// Returns Map with token and redirect_url
  Future<Map<String, dynamic>> createTransaction({
    required String orderId,
    required int grossAmount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    List<Map<String, dynamic>>? itemDetails,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/transactions');

      final body = {
        'transaction_details': {
          'order_id': orderId,
          'gross_amount': grossAmount,
        },
        'customer_details': {
          'first_name': customerName,
          'email': customerEmail,
          'phone': customerPhone,
        },
        'enabled_payments': [
          'qris', // Only QRIS payment
          'gopay',
          'shopeepay',
        ],
        'item_details': itemDetails ??
            [
              {
                'id': orderId,
                'price': grossAmount,
                'quantity': 1,
                'name': 'Booking Payment',
              }
            ],
      };

      print('🔐 MIDTRANS: Creating transaction...');
      print('   Order ID: $orderId');
      print('   Amount: Rp $grossAmount');
      print('   Customer: $customerName ($customerEmail)');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': _basicAuth,
        },
        body: jsonEncode(body),
      );

      print('📡 MIDTRANS: Response status = ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ MIDTRANS: Snap token generated successfully');
        print('   Token: ${data['token']}');

        return {
          'success': true,
          'token': data['token'],
          'redirect_url': data['redirect_url'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        print('❌ MIDTRANS: Failed to create transaction');
        print('   Error: ${errorData['error_messages']}');

        return {
          'success': false,
          'error': errorData['error_messages']?.toString() ??
              'Failed to create transaction',
        };
      }
    } catch (e, stackTrace) {
      print('❌ MIDTRANS: Exception occurred');
      print('   Error: $e');
      print('   Stack: $stackTrace');

      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Check transaction status
  /// Returns transaction status and details
  Future<Map<String, dynamic>> checkTransactionStatus(String orderId) async {
    try {
      final url = Uri.parse('$_apiBaseUrl/$orderId/status');

      print('🔍 MIDTRANS: Checking transaction status...');
      print('   Order ID: $orderId');

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': _basicAuth,
        },
      );

      print('📡 MIDTRANS: Status check response = ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['transaction_status'];
        final paymentType = data['payment_type'];

        print('✅ MIDTRANS: Transaction status retrieved');
        print('   Status: $status');
        print('   Payment Type: $paymentType');

        return {
          'success': true,
          'transaction_status': status,
          'payment_type': paymentType,
          'fraud_status': data['fraud_status'],
          'status_code': data['status_code'],
          'gross_amount': data['gross_amount'],
          'settlement_time': data['settlement_time'],
          'data': data,
        };
      } else {
        print('❌ MIDTRANS: Failed to check status');
        return {
          'success': false,
          'error': 'Failed to check transaction status',
        };
      }
    } catch (e) {
      print('❌ MIDTRANS: Exception while checking status');
      print('   Error: $e');

      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Charge transaction with QRIS
  /// Returns QRIS string for QR code display
  Future<Map<String, dynamic>> chargeQris({
    required String orderId,
    required int grossAmount,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    List<Map<String, dynamic>>? itemDetails,
  }) async {
    try {
      final url = Uri.parse('$_apiBaseUrl/charge');

      final body = {
        'payment_type': 'qris',
        'transaction_details': {
          'order_id': orderId,
          'gross_amount': grossAmount,
        },
        'customer_details': {
          'first_name': customerName,
          'email': customerEmail,
          'phone': customerPhone,
        },
        'item_details': itemDetails ??
            [
              {
                'id': orderId,
                'price': grossAmount,
                'quantity': 1,
                'name': 'Booking Payment',
              }
            ],
      };

      print('🔐 MIDTRANS: Charging QRIS transaction...');
      print('   Order ID: $orderId');
      print('   Amount: Rp $grossAmount');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': _basicAuth,
        },
        body: jsonEncode(body),
      );

      print('📡 MIDTRANS: Charge response status = ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ MIDTRANS: QRIS charge successful');

        // Get QRIS actions
        final actions = data['actions'] as List?;
        String? qrisString;

        if (actions != null) {
          for (var action in actions) {
            if (action['name'] == 'generate-qr-code') {
              qrisString = action['url'];
              break;
            }
          }
        }

        print('   Transaction ID: ${data['transaction_id']}');
        print('   Transaction Status: ${data['transaction_status']}');
        print('   QRIS String: ${qrisString != null ? 'Found' : 'Not found'}');

        return {
          'success': true,
          'transaction_id': data['transaction_id'],
          'transaction_status': data['transaction_status'],
          'order_id': data['order_id'],
          'qris_string': qrisString,
          'expiry_time': data['expiry_time'],
          'data': data,
        };
      } else {
        final errorData = jsonDecode(response.body);
        print('❌ MIDTRANS: Failed to charge QRIS');
        print('   Error: ${errorData['error_messages']}');

        return {
          'success': false,
          'error': errorData['error_messages']?.toString() ??
              'Failed to charge QRIS',
        };
      }
    } catch (e, stackTrace) {
      print('❌ MIDTRANS: Exception occurred during QRIS charge');
      print('   Error: $e');
      print('   Stack: $stackTrace');

      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Cancel transaction
  Future<Map<String, dynamic>> cancelTransaction(String orderId) async {
    try {
      final url = Uri.parse('$_apiBaseUrl/$orderId/cancel');

      print('🚫 MIDTRANS: Cancelling transaction...');
      print('   Order ID: $orderId');

      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': _basicAuth,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ MIDTRANS: Transaction cancelled');

        return {
          'success': true,
          'data': data,
        };
      } else {
        print('❌ MIDTRANS: Failed to cancel transaction');
        return {
          'success': false,
          'error': 'Failed to cancel transaction',
        };
      }
    } catch (e) {
      print('❌ MIDTRANS: Exception while cancelling');
      print('   Error: $e');

      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get Snap URL for WebView
  String getSnapUrl(String token) {
    return 'https://app.sandbox.midtrans.com/snap/v2/vtweb/$token';
  }

  /// Parse transaction status to payment status
  String parseTransactionStatus(String transactionStatus) {
    switch (transactionStatus) {
      case 'capture':
      case 'settlement':
        return 'paid';
      case 'pending':
        return 'pending';
      case 'deny':
      case 'cancel':
      case 'expire':
        return 'failed';
      default:
        return 'pending';
    }
  }

  /// Validate Server Key configuration
  bool isConfigured() {
    return serverKey.isNotEmpty && clientKey.isNotEmpty;
  }
}
