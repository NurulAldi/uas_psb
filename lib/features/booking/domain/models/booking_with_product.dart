import 'package:rentlens/features/booking/domain/models/booking.dart';
import 'package:rentlens/features/products/domain/models/product.dart';

/// Booking with Product Details
/// Combines booking data with product information for display
/// Now includes user name for owner management screen
class BookingWithProduct {
  final Booking booking;
  final Product product;
  final String userName;

  const BookingWithProduct({
    required this.booking,
    required this.product,
    required this.userName,
  });

  /// Create from JSON (Supabase joined query)
  factory BookingWithProduct.fromJson(Map<String, dynamic> json) {
    // Check if data is from bookings_with_details view (flat structure)
    // or from a joined query with nested objects
    final bool isFromView = json.containsKey('product_name');

    if (isFromView) {
      // Data from bookings_with_details view - flat structure
      return BookingWithProduct.fromViewJson(json);
    } else {
      // Data from joined query - nested structure
      return BookingWithProduct(
        booking: Booking.fromJson(json),
        product: Product.fromJson(json['products'] as Map<String, dynamic>),
        userName: json['user_name'] as String? ?? 'Unknown User',
      );
    }
  }

  /// Create from bookings_with_details view (flat structure)
  factory BookingWithProduct.fromViewJson(Map<String, dynamic> json) {
    // Reconstruct Product from flat fields
    final productJson = {
      'id': json['product_id'],
      'name': json['product_name'],
      'category': json['product_category'],
      'description': '', // Not included in view
      'price_per_day': json['product_price'],
      'image_url': json['product_image'],
      'is_available': true, // Assume available
      'owner_id': json['owner_id'],
      'created_at': json['created_at'], // Use booking created_at as fallback
      'updated_at': json['updated_at'], // Use booking updated_at as fallback
    };

    return BookingWithProduct(
      booking: Booking.fromJson(json),
      product: Product.fromJson(productJson),
      userName: json['renter_name'] as String? ?? 'Unknown User',
    );
  }

  /// Getters for convenience - Booking fields
  String get id => booking.id;
  String get userId => booking.userId;
  String get productId => booking.productId;
  DateTime get startDate => booking.startDate;
  DateTime get endDate => booking.endDate;
  double get totalPrice => booking.totalPrice;
  BookingStatus get status => booking.status;
  BookingPaymentStatus get paymentStatus => booking.paymentStatus; // ✨ NEW
  String? get paymentProofUrl => booking.paymentProofUrl;
  DateTime get createdAt => booking.createdAt;
  DateTime get updatedAt => booking.updatedAt;

  // Delivery fields
  DeliveryMethod get deliveryMethod => booking.deliveryMethod;
  double get deliveryFee => booking.deliveryFee;
  double? get distanceKm => booking.distanceKm;
  String? get ownerId => booking.ownerId;
  String? get renterAddress => booking.renterAddress;
  String? get notes => booking.notes;

  /// Product fields
  String get productName => product.name;
  String? get productImageUrl => product.imageUrl;
  ProductCategory get productCategory => product.category;
  double get pricePerDay => product.pricePerDay;

  /// Get formatted values
  int get numberOfDays => booking.numberOfDays;
  String get formattedTotalPrice => booking.formattedTotalPrice;
  String get formattedDeliveryFee => booking.formattedDeliveryFee;
  double get productSubtotal => booking.productSubtotal;
  String get statusText => booking.statusText;
  String get statusColor => booking.statusColor;

  // ✨ NEW: Payment-related getters
  bool get isPaymentCompleted => booking.isPaymentCompleted;
  bool get canBeConfirmedByOwner => booking.canBeConfirmedByOwner;
  String get paymentStatusText => booking.paymentStatusText;
  String get userFriendlyStatus => booking.userFriendlyStatus;

  @override
  String toString() {
    return 'BookingWithProduct(id: $id, product: $productName, status: ${status.value}, user: $userName)';
  }
}
