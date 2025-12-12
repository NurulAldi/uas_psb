import 'dart:io';
import 'package:rentlens/core/config/supabase_config.dart';
import 'package:rentlens/features/booking/domain/models/booking.dart';
import 'package:rentlens/features/booking/domain/models/booking_with_product.dart';

/// Booking Repository
/// Handles all data operations related to bookings
class BookingRepository {
  final _supabase = SupabaseConfig.client;

  /// Create a new booking
  Future<Booking> createBooking({
    required String productId,
    required DateTime startDate,
    required DateTime endDate,
    required double totalPrice,
  }) async {
    try {
      print('📦 BOOKING REPOSITORY: Creating booking...');

      // Use guest user ID for bookings without authentication
      final userId = SupabaseConfig.currentUserId ??
          '00000000-0000-0000-0000-000000000000';

      print('📦 User ID (guest mode): $userId');
      print('📦 Product ID: $productId');
      print('📦 Start Date: ${startDate.toIso8601String().split('T')[0]}');
      print('📦 End Date: ${endDate.toIso8601String().split('T')[0]}');
      print('📦 Total Price: $totalPrice');

      // Prepare booking data
      final bookingData = {
        'user_id': userId,
        'product_id': productId,
        'start_date': startDate.toIso8601String().split('T')[0], // Date only
        'end_date': endDate.toIso8601String().split('T')[0], // Date only
        'total_price': totalPrice,
        'status': BookingStatus.pending.value,
      };

      print('📦 Booking data: $bookingData');

      // Insert booking into database
      final response = await _supabase
          .from('bookings')
          .insert(bookingData)
          .select()
          .single();

      print('✅ BOOKING REPOSITORY: Booking created successfully');
      print('📦 Response: $response');

      return Booking.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ BOOKING REPOSITORY: Error creating booking = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all bookings for current user
  Future<List<Booking>> getUserBookings() async {
    try {
      print('📦 BOOKING REPOSITORY: Fetching user bookings...');

      // Get current user ID - return empty if not logged in
      final userId = SupabaseConfig.currentUserId;

      if (userId == null) {
        print('❌ No user logged in - returning empty list');
        return [];
      }

      print('   User ID: $userId');

      final response = await _supabase
          .from('bookings')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('📦 BOOKING REPOSITORY: Received ${response.length} bookings');

      final bookings = (response as List)
          .map((json) => Booking.fromJson(json as Map<String, dynamic>))
          .toList();

      return bookings;
    } catch (e, stackTrace) {
      print('❌ BOOKING REPOSITORY: Error fetching user bookings = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get booking by ID
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      print('📦 BOOKING REPOSITORY: Fetching booking with ID: $bookingId');

      final response = await _supabase
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .single();

      print('📦 BOOKING REPOSITORY: Booking found');

      return Booking.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ BOOKING REPOSITORY: Error fetching booking by ID = $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Update booking status
  /// ✨ UPDATED: Now validates payment status before confirming
  Future<Booking> updateBookingStatus({
    required String bookingId,
    required BookingStatus status,
  }) async {
    try {
      print('📦 BOOKING REPOSITORY: Updating booking status...');

      // ✨ NEW: If owner is trying to confirm, check payment first
      if (status == BookingStatus.confirmed) {
        final booking = await getBookingById(bookingId);
        if (booking == null) {
          throw Exception('Booking not found');
        }

        // ✨ VALIDATION: Payment must be completed
        if (booking.paymentStatus != BookingPaymentStatus.paid) {
          throw Exception(
            'Tidak bisa menerima booking. Pembayaran belum selesai. '
            'Status pembayaran saat ini: ${booking.paymentStatusText}',
          );
        }

        print('✅ Payment verified: PAID');
      }

      final response = await _supabase
          .from('bookings')
          .update({'status': status.value})
          .eq('id', bookingId)
          .select()
          .single();

      print('✅ BOOKING REPOSITORY: Booking status updated');

      return Booking.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ BOOKING REPOSITORY: Error updating booking status = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Cancel booking
  Future<Booking> cancelBooking(String bookingId) async {
    return updateBookingStatus(
      bookingId: bookingId,
      status: BookingStatus.cancelled,
    );
  }

  /// Upload payment proof
  Future<Booking> uploadPaymentProof({
    required String bookingId,
    required String paymentProofUrl,
  }) async {
    try {
      print('📦 BOOKING REPOSITORY: Uploading payment proof...');

      final response = await _supabase
          .from('bookings')
          .update({'payment_proof_url': paymentProofUrl})
          .eq('id', bookingId)
          .select()
          .single();

      print('✅ BOOKING REPOSITORY: Payment proof uploaded');

      return Booking.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ BOOKING REPOSITORY: Error uploading payment proof = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if product is available for date range
  Future<bool> checkProductAvailability({
    required String productId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      print('📦 BOOKING REPOSITORY: Checking product availability...');
      print('📦 Product ID: $productId');
      print('📦 Start Date: ${startDate.toIso8601String().split('T')[0]}');
      print('📦 End Date: ${endDate.toIso8601String().split('T')[0]}');

      // Check for overlapping bookings
      final response = await _supabase
          .from('bookings')
          .select()
          .eq('product_id', productId)
          .inFilter('status', [
        'pending',
        'confirmed',
        'active'
      ]).or('start_date.lte.${endDate.toIso8601String().split('T')[0]},end_date.gte.${startDate.toIso8601String().split('T')[0]}');

      print(
          '📦 BOOKING REPOSITORY: Found ${response.length} conflicting bookings');

      return response.isEmpty;
    } catch (e, stackTrace) {
      print('❌ BOOKING REPOSITORY: Error checking availability = $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Get bookings by status
  Future<List<Booking>> getBookingsByStatus(BookingStatus status) async {
    try {
      print(
          '📦 BOOKING REPOSITORY: Fetching bookings with status: ${status.value}');

      // Use guest user ID for bookings without authentication
      final userId = SupabaseConfig.currentUserId ??
          '00000000-0000-0000-0000-000000000000';

      final response = await _supabase
          .from('bookings')
          .select()
          .eq('user_id', userId)
          .eq('status', status.value)
          .order('created_at', ascending: false);

      print('📦 BOOKING REPOSITORY: Received ${response.length} bookings');

      final bookings = (response as List)
          .map((json) => Booking.fromJson(json as Map<String, dynamic>))
          .toList();

      return bookings;
    } catch (e, stackTrace) {
      print('❌ BOOKING REPOSITORY: Error fetching bookings by status = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get bookings with product details (joined query)
  Future<List<BookingWithProduct>> getUserBookingsWithProducts() async {
    try {
      print('📦 ========== FETCHING USER BOOKINGS ==========');

      // Get current user ID
      final userId = SupabaseConfig.currentUserId;

      print('   Current User ID: $userId');

      if (userId == null) {
        print('❌ No user logged in - returning empty list');
        return [];
      }

      final response = await _supabase
          .from('bookings')
          .select('*, products(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('   Found ${response.length} bookings for user: $userId');

      if (response.isEmpty) {
        print('   No bookings found');
        return [];
      }

      final bookingsWithProducts = (response as List).map((json) {
        final booking = json as Map<String, dynamic>;
        print(
            '   - Booking ID: ${booking['id']}, Product: ${booking['products']?['name'] ?? 'Unknown'}');
        return BookingWithProduct.fromJson(booking);
      }).toList();

      print('✅ ========== USER BOOKINGS LOADED ==========');
      return bookingsWithProducts;
    } catch (e, stackTrace) {
      print('❌ BOOKING REPOSITORY: Error fetching bookings with products = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all bookings for products owned by the specified owner
  Future<List<BookingWithProduct>> getOwnerBookings(String ownerId) async {
    try {
      print('📦 BOOKING REPOSITORY: Fetching bookings for owner: $ownerId');

      // Use bookings_with_details view for complete info
      final response = await _supabase
          .from('bookings_with_details')
          .select()
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false);

      print(
          '📦 BOOKING REPOSITORY: Received ${response.length} bookings for owner');

      final bookingsWithProducts = (response as List)
          .map((json) =>
              BookingWithProduct.fromJson(json as Map<String, dynamic>))
          .toList();

      return bookingsWithProducts;
    } catch (e, stackTrace) {
      print('❌ BOOKING REPOSITORY: Error fetching owner bookings = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get booking by ID with product details (for both owner and renter)
  Future<BookingWithProduct?> getBookingWithProductById(
      String bookingId) async {
    try {
      print(
          '📦 BOOKING REPOSITORY: Fetching booking with product by ID: $bookingId');

      // Use bookings_with_details view for complete info
      final response = await _supabase
          .from('bookings_with_details')
          .select()
          .eq('id', bookingId)
          .maybeSingle();

      if (response == null) {
        print('📦 BOOKING REPOSITORY: Booking not found');
        return null;
      }

      print('📦 BOOKING REPOSITORY: Booking found');
      return BookingWithProduct.fromJson(response);
    } catch (e, stackTrace) {
      print(
          '❌ BOOKING REPOSITORY: Error fetching booking with product by ID = $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Upload payment proof image to Supabase Storage
  Future<String> uploadPaymentProofImage({
    required String bookingId,
    required File imageFile,
  }) async {
    try {
      print('📦 BOOKING REPOSITORY: Uploading payment proof image...');

      // Use guest user ID for bookings without authentication
      final userId = SupabaseConfig.currentUserId ??
          '00000000-0000-0000-0000-000000000000';

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final fileName = '${userId}_${bookingId}_$timestamp.$extension';
      final filePath = 'payment_proofs/$fileName';

      print('📦 Uploading to: $filePath');

      // Upload to Supabase Storage
      final uploadResponse = await _supabase.storage
          .from('payment_proofs')
          .upload(filePath, imageFile);

      print('✅ Image uploaded: $uploadResponse');

      // Get public URL
      final publicUrl =
          _supabase.storage.from('payment_proofs').getPublicUrl(filePath);

      print('📦 Public URL: $publicUrl');

      return publicUrl;
    } catch (e, stackTrace) {
      print('❌ BOOKING REPOSITORY: Error uploading payment proof = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Upload payment proof (upload image and update booking)
  Future<Booking> uploadPaymentProofComplete({
    required String bookingId,
    required File imageFile,
  }) async {
    try {
      print('📦 BOOKING REPOSITORY: Complete payment proof upload...');

      // Upload image to storage
      final imageUrl = await uploadPaymentProofImage(
        bookingId: bookingId,
        imageFile: imageFile,
      );

      // Update booking with image URL
      final booking = await uploadPaymentProof(
        bookingId: bookingId,
        paymentProofUrl: imageUrl,
      );

      print('✅ BOOKING REPOSITORY: Payment proof uploaded and booking updated');

      return booking;
    } catch (e, stackTrace) {
      print(
          '❌ BOOKING REPOSITORY: Error in complete payment proof upload = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
