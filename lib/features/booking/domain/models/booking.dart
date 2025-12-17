/// Delivery Method Enum
enum DeliveryMethod {
  pickup('pickup', 'Dijemput Sendiri', 'Penyewa mengambil dari pemilik'),
  delivery('delivery', 'Diantar', 'Pemilik mengantarkan ke penyewa');

  final String value;
  final String label;
  final String description;
  const DeliveryMethod(this.value, this.label, this.description);

  /// Create DeliveryMethod from string
  static DeliveryMethod fromString(String value) {
    return DeliveryMethod.values.firstWhere(
      (method) => method.value.toLowerCase() == value.toLowerCase(),
      orElse: () => DeliveryMethod.pickup,
    );
  }
}

/// Booking Status Enum
enum BookingStatus {
  pending('pending', 'Menunggu', 'Waiting for owner confirmation'),
  confirmed('confirmed', 'Dikonfirmasi', 'Owner accepted, ready to start'),
  active('active', 'Aktif', 'Currently renting'),
  completed('completed', 'Selesai', 'Rental finished'),
  cancelled('cancelled', 'Dibatalkan', 'Booking cancelled');

  final String value;
  final String label;
  final String description;
  const BookingStatus(this.value, this.label, this.description);

  /// Create BookingStatus from string
  static BookingStatus fromString(String value) {
    return BookingStatus.values.firstWhere(
      (status) => status.value.toLowerCase() == value.toLowerCase(),
      orElse: () => BookingStatus.pending,
    );
  }
}

/// Payment Status Enum (for Booking)
enum BookingPaymentStatus {
  pending('pending', 'Pending', 'Waiting for payment'),
  processing('processing', 'Processing', 'Payment processing'),
  paid('paid', 'Paid', 'Payment completed'),
  failed('failed', 'Failed', 'Payment failed'),
  expired('expired', 'Expired', 'Payment expired'),
  cancelled('cancelled', 'Cancelled', 'Payment cancelled');

  final String value;
  final String label;
  final String description;
  const BookingPaymentStatus(this.value, this.label, this.description);

  /// Create BookingPaymentStatus from string
  static BookingPaymentStatus fromString(String value) {
    return BookingPaymentStatus.values.firstWhere(
      (status) => status.value.toLowerCase() == value.toLowerCase(),
      orElse: () => BookingPaymentStatus.pending,
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
  final BookingPaymentStatus paymentStatus; // ✨ NEW: Payment status tracking
  final String? paymentProofUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Delivery fields
  final DeliveryMethod deliveryMethod;
  final double deliveryFee;
  final double? distanceKm;
  final String? ownerId;
  final String? renterAddress;
  final String? notes;

  const Booking({
    required this.id,
    required this.userId,
    required this.productId,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.status,
    this.paymentStatus = BookingPaymentStatus.pending, // ✨ NEW: Default pending
    this.paymentProofUrl,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryMethod = DeliveryMethod.pickup,
    this.deliveryFee = 0,
    this.distanceKm,
    this.ownerId,
    this.renterAddress,
    this.notes,
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
      paymentStatus: json['payment_status'] != null
          ? BookingPaymentStatus.fromString(json['payment_status'] as String)
          : BookingPaymentStatus.pending, // ✨ NEW: Parse payment status
      paymentProofUrl: json['payment_proof_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deliveryMethod: json['delivery_method'] != null
          ? DeliveryMethod.fromString(json['delivery_method'] as String)
          : DeliveryMethod.pickup,
      deliveryFee: json['delivery_fee'] != null
          ? (json['delivery_fee'] as num).toDouble()
          : 0,
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num).toDouble()
          : null,
      ownerId: json['owner_id'] as String?,
      renterAddress: json['renter_address'] as String?,
      notes: json['notes'] as String?,
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
      'delivery_method': deliveryMethod.value,
      'delivery_fee': deliveryFee,
      'distance_km': distanceKm,
      if (renterAddress != null) 'renter_address': renterAddress,
      if (notes != null) 'notes': notes,
    };
  }

  /// Calculate delivery fee based on distance
  /// Rp 5,000 per 2km (rounded up)
  static double calculateDeliveryFee(double distanceKm) {
    if (distanceKm <= 0) return 0;
    const baseFee = 5000.0; // Rp 5,000
    const distanceUnit = 2.0; // per 2km
    return (distanceKm / distanceUnit).ceil() * baseFee;
  }

  /// Get product subtotal (total - delivery fee)
  double get productSubtotal => totalPrice - deliveryFee;

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

  /// Format delivery fee as IDR
  String get formattedDeliveryFee {
    return 'Rp ${deliveryFee.toStringAsFixed(0).replaceAllMapped(
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
        return 'Menunggu';
      case BookingStatus.confirmed:
        return 'Dikonfirmasi';
      case BookingStatus.active:
        return 'Aktif';
      case BookingStatus.completed:
        return 'Selesai';
      case BookingStatus.cancelled:
        return 'Dibatalkan';
    }
  }

  /// ✨ NEW: Check if payment is completed
  bool get isPaymentCompleted => paymentStatus == BookingPaymentStatus.paid;

  /// ✨ NEW: Check if can be confirmed by owner
  /// Booking can only be confirmed if payment is completed
  bool get canBeConfirmedByOwner {
    return status == BookingStatus.pending && isPaymentCompleted;
  }

  /// ✨ NEW: Get payment status display text
  String get paymentStatusText {
    switch (paymentStatus) {
      case BookingPaymentStatus.pending:
        return 'Menunggu Pembayaran';
      case BookingPaymentStatus.processing:
        return 'Memproses Pembayaran';
      case BookingPaymentStatus.paid:
        return 'Sudah Dibayar';
      case BookingPaymentStatus.failed:
        return 'Pembayaran Gagal';
      case BookingPaymentStatus.expired:
        return 'Pembayaran Kadaluarsa';
      case BookingPaymentStatus.cancelled:
        return 'Pembayaran Dibatalkan';
    }
  }

  /// ✨ NEW: Get combined status for user display
  String get userFriendlyStatus {
    if (status == BookingStatus.pending) {
      if (paymentStatus == BookingPaymentStatus.pending) {
        return 'Menunggu Pembayaran';
      } else if (paymentStatus == BookingPaymentStatus.paid) {
        return 'Menunggu Konfirmasi Pemilik';
      } else {
        return 'Pembayaran ${paymentStatusText}';
      }
    }
    return statusText;
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
    BookingPaymentStatus? paymentStatus, // ✨ NEW
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
      paymentStatus: paymentStatus ?? this.paymentStatus, // ✨ NEW
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
