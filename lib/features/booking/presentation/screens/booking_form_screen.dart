import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rentlens/core/constants/app_strings.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/core/services/location_service.dart';
import 'package:rentlens/features/products/providers/product_provider.dart';
import 'package:rentlens/features/products/domain/models/product.dart';
import 'package:rentlens/features/auth/controllers/auth_controller.dart'
    as auth_ctrl;
import 'package:rentlens/features/auth/providers/profile_provider.dart';
import 'package:rentlens/features/booking/domain/models/booking.dart';
import 'package:rentlens/features/booking/data/repositories/booking_repository.dart';

/// Complete Booking Form with Delivery Method Selection
/// Features:
/// - Date range picker
/// - Delivery method selection (pickup/delivery)
/// - Auto-calculate delivery fee based on distance
/// - Show complete price breakdown
/// - Validation and error handling
class BookingFormScreen extends ConsumerStatefulWidget {
  final String productId;

  const BookingFormScreen({super.key, required this.productId});

  @override
  ConsumerState<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends ConsumerState<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _locationService = LocationService();

  DateTime? _startDate;
  DateTime? _endDate;
  DeliveryMethod _deliveryMethod = DeliveryMethod.pickup;
  bool _isSubmitting = false;
  double? _distanceKm;
  double _deliveryFee = 0;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Calculate distance when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateDistance();
    });
  }

  Future<void> _calculateDistance() async {
    final productAsync = ref.read(productByIdProvider(widget.productId));
    final authAsync = ref.read(auth_ctrl.authStateProvider);
    final profile = authAsync.value?.user;

    productAsync.when(
      data: (product) async {
        if (product == null || product.ownerId == null) return;

        if (profile == null || !profile.hasLocation) return;

        // Get product owner's location
        final ownerProfile = await ref.read(
          profileByIdProvider(product.ownerId!).future,
        );

        if (ownerProfile == null || !ownerProfile.hasLocation) return;

        // Calculate distance
        final distance = _locationService.calculateDistance(
          startLat: profile.latitude!,
          startLon: profile.longitude!,
          endLat: ownerProfile.latitude!,
          endLon: ownerProfile.longitude!,
        );

        setState(() {
          _distanceKm = distance;
          _deliveryFee = Booking.calculateDeliveryFee(distance);
        });
      },
      loading: () {},
      error: (_, __) {},
    );
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Reset end date if it's before start date
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.selectStartDateFirst),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate!.add(const Duration(days: 1)),
      firstDate: _startDate!.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  int get _numberOfDays {
    if (_startDate == null || _endDate == null) return 0;
    return _endDate!.difference(_startDate!).inDays;
  }

  double _calculateTotalPrice(Product product) {
    final productPrice = _numberOfDays * product.pricePerDay;
    final deliveryCharge =
        _deliveryMethod == DeliveryMethod.delivery ? _deliveryFee : 0;
    return productPrice + deliveryCharge;
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.pleaseSelectRentalDates),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // Make dialog responsive on small screens and avoid horizontal overflow
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.primary),
            const SizedBox(width: 12),
            // Allow the title to wrap when space is constrained
            Expanded(
              child: Text(
                AppStrings.confirmBookingTitle,
                style: const TextStyle(fontSize: 18),
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          AppStrings.confirmBookingMessage,
          style: TextStyle(fontSize: 16),
          softWrap: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    // If user cancels, stay on booking form
    if (confirmed != true) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final productAsync = ref.read(productByIdProvider(widget.productId));
      final profileAsync = ref.read(currentUserProfileProvider);

      await productAsync.when(
        data: (product) async {
          if (product == null) throw Exception('Product not found');

          await profileAsync.when(
            data: (profile) async {
              if (profile == null) throw Exception('Profile not found');

              // Validate location for delivery
              if (_deliveryMethod == DeliveryMethod.delivery) {
                if (!profile.hasLocation) {
                  throw Exception(
                    'Please set your location in profile to use delivery',
                  );
                }
                if (_distanceKm == null) {
                  throw Exception('Unable to calculate delivery distance');
                }
              }

              final totalPrice = _calculateTotalPrice(product);

              final repository = BookingRepository();
              await repository.createBooking(
                productId: product.id,
                startDate: _startDate!,
                endDate: _endDate!,
                totalPrice: totalPrice,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text(AppStrings.bookingSubmittedSuccessfully),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                // Navigate back to product detail page
                context.go('/products/${widget.productId}');
              }
            },
            loading: () => throw Exception('Loading profile...'),
            error: (e, _) => throw Exception('Profile error: $e'),
          );
        },
        loading: () => throw Exception('Loading product...'),
        error: (e, _) => throw Exception('Product error: $e'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productByIdProvider(widget.productId));
    final authAsync = ref.watch(auth_ctrl.authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.newBooking),
        elevation: 0,
      ),
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return const Center(child: Text(AppStrings.productNotFound));
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Product Info Card
                _buildProductCard(product),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Date Selection
                        _buildDateSelection(),
                        const SizedBox(height: 24),

                        // Delivery Method Selection
                        _buildDeliveryMethodSelection(authAsync),
                        const SizedBox(height: 24),

                        // Notes
                        _buildNotesField(),
                        const SizedBox(height: 24),

                        // Price Breakdown
                        _buildPriceBreakdown(product),
                        const SizedBox(height: 32),

                        // Submit Button
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: product.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.camera_alt, size: 40),
                    ),
                  )
                : Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: const Icon(Icons.camera_alt, size: 40),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.category.name.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatPrice(product.pricePerDay),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'Rental Period',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _isSubmitting ? null : _selectStartDate,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Tanggal Mulai *',
              prefixIcon: const Icon(Icons.event),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _startDate == null
                  ? 'Pilih tanggal mulai'
                  : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
              style: TextStyle(
                color: _startDate == null ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _isSubmitting ? null : _selectEndDate,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Tanggal Selesai *',
              prefixIcon: const Icon(Icons.event),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _endDate == null
                  ? 'Pilih tanggal selesai'
                  : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
              style: TextStyle(
                color: _endDate == null ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ),
        if (_numberOfDays > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Duration: $_numberOfDays day${_numberOfDays > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.blue[900],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeliveryMethodSelection(AsyncValue profileAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_shipping, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'Metode Pengiriman',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...DeliveryMethod.values.map((method) {
          final isSelected = _deliveryMethod == method;
          final isDelivery = method == DeliveryMethod.delivery;

          // Get current user synchronously to make UI responsive
          final authState = profileAsync.value;
          final user = authState?.user;
          final isDisabled = isDelivery && (user == null || !user.hasLocation);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: _isSubmitting
                  ? null
                  : () {
                      if (isDisabled) {
                        // Inform user how to enable delivery
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please set your location in profile to use delivery',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setState(() => _deliveryMethod = method);
                    },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : (isDisabled ? Colors.grey[50] : Colors.white),
                ),
                child: Row(
                  children: [
                    Radio<DeliveryMethod>(
                      value: method,
                      groupValue: _deliveryMethod,
                      onChanged: _isSubmitting || isDisabled
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _deliveryMethod = value);
                              }
                            },
                      activeColor: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method.label,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDisabled
                                      ? Colors.grey[500]
                                      : Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            method.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDisabled
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                          if (isDelivery &&
                              isSelected &&
                              _distanceKm != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Distance: ${_locationService.formatDistance(_distanceKm!)} • Fee: ${_formatPrice(_deliveryFee)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.note, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text(
              'Additional Notes (Optional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          maxLength: 500,
          enabled: !_isSubmitting,
          decoration: InputDecoration(
            hintText: 'e.g., Special requests, preferred pickup time...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildPriceBreakdown(Product product) {
    final productPrice = _numberOfDays * product.pricePerDay;
    final deliveryCharge =
        _deliveryMethod == DeliveryMethod.delivery ? _deliveryFee : 0;
    final totalPrice = productPrice + deliveryCharge;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPriceRow(
            'Rental ($_numberOfDays day${_numberOfDays > 1 ? 's' : ''})',
            _formatPrice(productPrice),
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            'Product price/day',
            _formatPrice(product.pricePerDay),
            isSubItem: true,
          ),
          if (_deliveryMethod == DeliveryMethod.delivery) ...[
            const SizedBox(height: 8),
            _buildPriceRow(
              'Delivery fee',
              _formatPrice(deliveryCharge.toDouble()),
            ),
            if (_distanceKm != null) ...[
              const SizedBox(height: 4),
              _buildPriceRow(
                '${_locationService.formatDistance(_distanceKm!)} @ Rp 5,000/2km',
                '',
                isSubItem: true,
                isInfo: true,
              ),
            ],
          ],
          const Divider(height: 24),
          _buildPriceRow(
            'Total Price',
            _formatPrice(totalPrice),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    String value, {
    bool isTotal = false,
    bool isSubItem = false,
    bool isInfo = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: isSubItem ? 16 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal
                  ? FontWeight.bold
                  : isSubItem
                      ? FontWeight.normal
                      : FontWeight.w600,
              color: isInfo
                  ? Colors.grey[600]
                  : isTotal
                      ? Colors.black
                      : Colors.black87,
            ),
          ),
          if (value.isNotEmpty)
            Text(
              value,
              style: TextStyle(
                fontSize: isTotal ? 18 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                color: isTotal ? AppColors.primary : Colors.black87,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isValid = _startDate != null && _endDate != null;

    return ElevatedButton(
      onPressed: (_isSubmitting || !isValid) ? null : _submitBooking,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isSubmitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline),
                const SizedBox(width: 8),
                Text(
                  isValid
                      ? 'Konfirmasi Pesanan'
                      : 'Pilih Tanggal untuk Melanjutkan',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  String _formatPrice(double price) {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }
}
