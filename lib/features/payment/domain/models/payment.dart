/// Payment Status Enum
/// Represents the current status of a payment transaction
import 'package:rentlens/core/constants/app_strings.dart';

enum PaymentStatus {
  pending(
      'pending', AppStrings.paymentStatusPending, AppStrings.waitingForPayment),
  processing('processing', AppStrings.paymentStatusProcessing,
      AppStrings.paymentBeingProcessed),
  paid('paid', AppStrings.paymentStatusPaid,
      AppStrings.paymentSuccessDescription),
  failed('failed', AppStrings.paymentStatusFailed,
      AppStrings.paymentFailedDescription),
  expired('expired', AppStrings.paymentStatusExpired,
      AppStrings.paymentLinkExpired),
  cancelled('cancelled', AppStrings.paymentStatusCancelled,
      AppStrings.paymentCancelledDescription);

  final String value;
  final String label;
  final String description;

  const PaymentStatus(this.value, this.label, this.description);

  /// Create from string value
  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => PaymentStatus.pending,
    );
  }

  /// Get color for status badge
  String get colorName {
    switch (this) {
      case PaymentStatus.pending:
        return 'orange';
      case PaymentStatus.processing:
        return 'blue';
      case PaymentStatus.paid:
        return 'green';
      case PaymentStatus.failed:
        return 'red';
      case PaymentStatus.expired:
        return 'gray';
      case PaymentStatus.cancelled:
        return 'gray';
    }
  }
}

/// Payment Method Enum
enum PaymentMethod {
  qris('qris', 'QRIS', 'Scan QR Code'),
  gopay('gopay', 'GoPay', 'GoPay E-Wallet'),
  shopeepay('shopeepay', 'ShopeePay', 'ShopeePay E-Wallet'),
  bankTransfer('bank_transfer', 'Bank Transfer', 'Virtual Account');

  final String value;
  final String label;
  final String description;

  const PaymentMethod(this.value, this.label, this.description);

  /// Create from string value
  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.value == value,
      orElse: () => PaymentMethod.qris,
    );
  }
}

/// Payment Model
/// Represents a payment transaction for a booking
class Payment {
  final String id;
  final String bookingId;
  final String orderId; // Midtrans order ID
  final int amount;
  final PaymentStatus status;
  final PaymentMethod method;
  final String? snapToken; // Midtrans snap token
  final String? snapUrl; // Midtrans payment URL
  final String? transactionId; // Midtrans transaction ID
  final String? fraudStatus;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Payment({
    required this.id,
    required this.bookingId,
    required this.orderId,
    required this.amount,
    required this.status,
    required this.method,
    this.snapToken,
    this.snapUrl,
    this.transactionId,
    this.fraudStatus,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from JSON
  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      orderId: json['order_id'] as String,
      amount: json['amount'] is String
          ? int.parse(json['amount'])
          : (json['amount'] as num).toInt(),
      status: PaymentStatus.fromString(json['status'] as String),
      method: PaymentMethod.fromString(json['method'] as String),
      snapToken: json['snap_token'] as String?,
      snapUrl: json['snap_url'] as String?,
      transactionId: json['transaction_id'] as String?,
      fraudStatus: json['fraud_status'] as String?,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to JSON for database insert
  Map<String, dynamic> toInsertJson() {
    return {
      'booking_id': bookingId,
      'order_id': orderId,
      'amount': amount,
      'status': status.value,
      'method': method.value,
      'snap_token': snapToken,
      'snap_url': snapUrl,
      'transaction_id': transactionId,
      'fraud_status': fraudStatus,
      'paid_at': paidAt?.toIso8601String(),
    };
  }

  /// Convert to JSON for database update
  Map<String, dynamic> toUpdateJson() {
    return {
      'status': status.value,
      'transaction_id': transactionId,
      'fraud_status': fraudStatus,
      'paid_at': paidAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Get formatted amount
  String get formattedAmount {
    return 'Rp ${amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  /// Check if payment is pending
  bool get isPending =>
      status == PaymentStatus.pending || status == PaymentStatus.processing;

  /// Check if payment is successful
  bool get isSuccess => status == PaymentStatus.paid;

  /// Check if payment is failed
  bool get isFailed =>
      status == PaymentStatus.failed ||
      status == PaymentStatus.expired ||
      status == PaymentStatus.cancelled;

  /// Copy with method
  Payment copyWith({
    String? id,
    String? bookingId,
    String? orderId,
    int? amount,
    PaymentStatus? status,
    PaymentMethod? method,
    String? snapToken,
    String? snapUrl,
    String? transactionId,
    String? fraudStatus,
    DateTime? paidAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Payment(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      orderId: orderId ?? this.orderId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      method: method ?? this.method,
      snapToken: snapToken ?? this.snapToken,
      snapUrl: snapUrl ?? this.snapUrl,
      transactionId: transactionId ?? this.transactionId,
      fraudStatus: fraudStatus ?? this.fraudStatus,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Payment(id: $id, orderId: $orderId, amount: $amount, status: ${status.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Payment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
