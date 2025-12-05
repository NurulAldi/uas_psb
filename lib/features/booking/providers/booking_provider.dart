import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/booking/data/repositories/booking_repository.dart';
import 'package:rentlens/features/booking/domain/models/booking.dart';
import 'package:rentlens/features/booking/domain/models/booking_with_product.dart';

/// Booking Repository Provider
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository();
});

/// User Bookings Provider
/// Fetches all bookings for the current user
final userBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getUserBookings();
});

/// Single Booking Provider
/// Fetches a single booking by ID
final bookingByIdProvider =
    FutureProvider.family<Booking?, String>((ref, bookingId) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getBookingById(bookingId);
});

/// Bookings by Status Provider
/// Fetches bookings filtered by status
final bookingsByStatusProvider =
    FutureProvider.family<List<Booking>, BookingStatus>((ref, status) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getBookingsByStatus(status);
});

/// Product Availability Provider
/// Checks if a product is available for a date range
final productAvailabilityProvider =
    FutureProvider.family<bool, ProductAvailabilityCheck>((ref, params) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.checkProductAvailability(
    productId: params.productId,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

/// Helper class for product availability check parameters
class ProductAvailabilityCheck {
  final String productId;
  final DateTime startDate;
  final DateTime endDate;

  ProductAvailabilityCheck({
    required this.productId,
    required this.startDate,
    required this.endDate,
  });
}

/// Booking State Notifier
/// Manages booking creation state
class BookingNotifier extends StateNotifier<AsyncValue<Booking?>> {
  final BookingRepository _repository;

  BookingNotifier(this._repository) : super(const AsyncValue.data(null));

  /// Create a new booking
  Future<Booking?> createBooking({
    required String productId,
    required DateTime startDate,
    required DateTime endDate,
    required double totalPrice,
  }) async {
    try {
      print('🔵 BOOKING PROVIDER: Creating booking...');
      state = const AsyncValue.loading();

      final booking = await _repository.createBooking(
        productId: productId,
        startDate: startDate,
        endDate: endDate,
        totalPrice: totalPrice,
      );

      print('✅ BOOKING PROVIDER: Booking created successfully');
      state = AsyncValue.data(booking);
      return booking;
    } catch (e, stackTrace) {
      print('❌ BOOKING PROVIDER: Error creating booking = $e');
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Update booking status
  Future<Booking?> updateBookingStatus({
    required String bookingId,
    required BookingStatus status,
  }) async {
    try {
      print('🔵 BOOKING PROVIDER: Updating booking status...');
      state = const AsyncValue.loading();

      final booking = await _repository.updateBookingStatus(
        bookingId: bookingId,
        status: status,
      );

      print('✅ BOOKING PROVIDER: Booking status updated');
      state = AsyncValue.data(booking);
      return booking;
    } catch (e, stackTrace) {
      print('❌ BOOKING PROVIDER: Error updating booking status = $e');
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Cancel booking
  Future<Booking?> cancelBooking(String bookingId) async {
    return updateBookingStatus(
      bookingId: bookingId,
      status: BookingStatus.cancelled,
    );
  }

  /// Upload payment proof
  Future<Booking?> uploadPaymentProof({
    required String bookingId,
    required String paymentProofUrl,
  }) async {
    try {
      print('🔵 BOOKING PROVIDER: Uploading payment proof...');
      state = const AsyncValue.loading();

      final booking = await _repository.uploadPaymentProof(
        bookingId: bookingId,
        paymentProofUrl: paymentProofUrl,
      );

      print('✅ BOOKING PROVIDER: Payment proof uploaded');
      state = AsyncValue.data(booking);
      return booking;
    } catch (e, stackTrace) {
      print('❌ BOOKING PROVIDER: Error uploading payment proof = $e');
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Reset state
  void reset() {
    state = const AsyncValue.data(null);
  }
}

/// Booking State Provider
final bookingNotifierProvider =
    StateNotifierProvider<BookingNotifier, AsyncValue<Booking?>>((ref) {
  final repository = ref.watch(bookingRepositoryProvider);
  return BookingNotifier(repository);
});

/// User Bookings With Products Provider
/// Fetches all bookings for the current user with product details
final userBookingsWithProductsProvider =
    FutureProvider<List<BookingWithProduct>>((ref) async {
  final repository = ref.watch(bookingRepositoryProvider);
  return repository.getUserBookingsWithProducts();
});

/// Payment Proof Upload Notifier
/// Manages payment proof upload state
class PaymentProofNotifier extends StateNotifier<AsyncValue<Booking?>> {
  final BookingRepository _repository;

  PaymentProofNotifier(this._repository) : super(const AsyncValue.data(null));

  /// Upload payment proof image and update booking
  Future<Booking?> uploadPaymentProof({
    required String bookingId,
    required File imageFile,
  }) async {
    try {
      print('🔵 PAYMENT PROOF PROVIDER: Uploading payment proof...');
      state = const AsyncValue.loading();

      final booking = await _repository.uploadPaymentProofComplete(
        bookingId: bookingId,
        imageFile: imageFile,
      );

      print('✅ PAYMENT PROOF PROVIDER: Payment proof uploaded successfully');
      state = AsyncValue.data(booking);
      return booking;
    } catch (e, stackTrace) {
      print('❌ PAYMENT PROOF PROVIDER: Error uploading payment proof = $e');
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Reset state
  void reset() {
    state = const AsyncValue.data(null);
  }
}

/// Payment Proof State Provider
final paymentProofNotifierProvider =
    StateNotifierProvider<PaymentProofNotifier, AsyncValue<Booking?>>((ref) {
  final repository = ref.watch(bookingRepositoryProvider);
  return PaymentProofNotifier(repository);
});
