/// Booking Status Enum
enum BookingStatus {
  pending('pending'),
  confirmed('confirmed'),
  active('active'),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  const BookingStatus(this.value);

  /// Create BookingStatus from string
  static BookingStatus fromString(String value) {
    return BookingStatus.values.firstWhere(
      (status) => status.value.toLowerCase() == value.toLowerCase(),
      orElse: () => BookingStatus.pending,
    );
  }
}

/// Booking Domain Model
class Booking {
  final String id;
  final String userId;
  final String productId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final BookingStatus status;
  final String? paymentProofUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Booking({
    required this.id,
    required this.userId,
    required this.productId,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.status,
    this.paymentProofUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create Booking from JSON (Supabase response)
  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      productId: json['product_id'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      totalPrice: (json['total_price'] as num).toDouble(),
      status: BookingStatus.fromString(json['status'] as String),
      paymentProofUrl: json['payment_proof_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert Booking to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'start_date': startDate.toIso8601String().split('T')[0], // Date only
      'end_date': endDate.toIso8601String().split('T')[0], // Date only
      'total_price': totalPrice,
      'status': status.value,
      'payment_proof_url': paymentProofUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Convert to JSON for insert (without id, createdAt, updatedAt)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'product_id': productId,
      'start_date': startDate.toIso8601String().split('T')[0], // Date only
      'end_date': endDate.toIso8601String().split('T')[0], // Date only
      'total_price': totalPrice,
      'status': status.value,
      'payment_proof_url': paymentProofUrl,
    };
  }

  /// Calculate number of days
  int get numberOfDays {
    return endDate.difference(startDate).inDays;
  }

  /// Format total price as IDR
  String get formattedTotalPrice {
    return 'Rp ${totalPrice.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  /// Get status color
  String get statusColor {
    switch (status) {
      case BookingStatus.pending:
        return 'yellow';
      case BookingStatus.confirmed:
        return 'blue';
      case BookingStatus.active:
        return 'green';
      case BookingStatus.completed:
        return 'gray';
      case BookingStatus.cancelled:
        return 'red';
    }
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending Confirmation';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.active:
        return 'Active';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Copy with method for immutability
  Booking copyWith({
    String? id,
    String? userId,
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
    double? totalPrice,
    BookingStatus? status,
    String? paymentProofUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Booking(id: $id, userId: $userId, productId: $productId, startDate: $startDate, endDate: $endDate, status: ${status.value})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Booking && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Create Booking Request DTO
class CreateBookingRequest {
  final String productId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;

  const CreateBookingRequest({
    required this.productId,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
  });

  /// Calculate number of days
  int get numberOfDays {
    return endDate.difference(startDate).inDays;
  }

  /// Validate booking request
  bool validate() {
    // End date must be after start date
    if (!endDate.isAfter(startDate)) return false;

    // Start date must be today or in the future
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final startDateOnly =
        DateTime(startDate.year, startDate.month, startDate.day);
    if (startDateOnly.isBefore(todayDate)) return false;

    // Total price must be positive
    if (totalPrice <= 0) return false;

    return true;
  }

  /// Get validation error message
  String? getValidationError() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final startDateOnly =
        DateTime(startDate.year, startDate.month, startDate.day);

    if (!endDate.isAfter(startDate)) {
      return 'End date must be after start date';
    }

    if (startDateOnly.isBefore(todayDate)) {
      return 'Start date cannot be in the past';
    }

    if (totalPrice <= 0) {
      return 'Total price must be greater than zero';
    }

    return null;
  }
}
