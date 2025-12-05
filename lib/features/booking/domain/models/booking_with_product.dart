import 'package:rentlens/features/booking/domain/models/booking.dart';
import 'package:rentlens/features/products/domain/models/product.dart';

/// Booking with Product Details
/// Combines booking data with product information for display
class BookingWithProduct {
  final Booking booking;
  final Product product;

  const BookingWithProduct({
    required this.booking,
    required this.product,
  });

  /// Create from JSON (Supabase joined query)
  factory BookingWithProduct.fromJson(Map<String, dynamic> json) {
    return BookingWithProduct(
      booking: Booking.fromJson(json),
      product: Product.fromJson(json['products'] as Map<String, dynamic>),
    );
  }

  /// Getters for convenience
  String get id => booking.id;
  String get userId => booking.userId;
  String get productId => booking.productId;
  DateTime get startDate => booking.startDate;
  DateTime get endDate => booking.endDate;
  double get totalPrice => booking.totalPrice;
  BookingStatus get status => booking.status;
  String? get paymentProofUrl => booking.paymentProofUrl;
  DateTime get createdAt => booking.createdAt;
  DateTime get updatedAt => booking.updatedAt;

  String get productName => product.name;
  String? get productImageUrl => product.imageUrl;
  ProductCategory get productCategory => product.category;
  double get pricePerDay => product.pricePerDay;

  /// Get formatted values
  int get numberOfDays => booking.numberOfDays;
  String get formattedTotalPrice => booking.formattedTotalPrice;
  String get statusText => booking.statusText;
  String get statusColor => booking.statusColor;

  @override
  String toString() {
    return 'BookingWithProduct(id: $id, product: $productName, status: ${status.value})';
  }
}
