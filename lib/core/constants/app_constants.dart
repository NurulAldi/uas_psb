/// App-wide Constants
class AppConstants {
  // API Constants
  static const int apiTimeout = 30; // seconds
  static const int maxRetries = 3;

  // Pagination
  static const int itemsPerPage = 20;
  static const int initialPage = 0;

  // Image
  static const double maxImageSize = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  // Booking
  static const int minBookingDays = 1;
  static const int maxBookingDays = 30;
  static const int maxAdvanceBookingDays = 90;

  // Validation
  static const int minPasswordLength = 8;
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 15;

  // Storage Buckets (Supabase)
  static const String avatarBucket = 'avatars';
  static const String productImageBucket = 'product-images';
  static const String paymentProofBucket = 'payment-proofs';

  // Date Formats
  static const String dateFormat = 'dd MMM yyyy';
  static const String dateTimeFormat = 'dd MMM yyyy, HH:mm';
  static const String timeFormat = 'HH:mm';

  // Product Categories
  static const List<String> productCategories = [
    'DSLR',
    'Mirrorless',
    'Drone',
    'Lens',
  ];

  // Booking Status
  static const List<String> bookingStatuses = [
    'pending',
    'confirmed',
    'active',
    'completed',
    'cancelled',
  ];

  // Error Messages
  static const String networkError =
      'Network error. Please check your connection.';
  static const String genericError = 'Something went wrong. Please try again.';
  static const String authError = 'Authentication failed. Please login again.';
  static const String notFoundError = 'Resource not found.';
}
