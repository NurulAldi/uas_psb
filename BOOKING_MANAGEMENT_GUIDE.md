# Booking Management System - Feature Guide

## Overview
Complete booking management system with delivery method selection (pickup/delivery), automatic delivery fee calculation, and owner booking management workflow.

## Features

### 1. Delivery Method Selection (User/Renter Side)
**Location**: `lib/features/booking/presentation/screens/booking_form_screen.dart`

#### Features:
- **Two delivery methods**:
  - **Pickup**: Renter picks up product from owner's location (free)
  - **Delivery**: Owner delivers product to renter's location (calculated fee)

- **Automatic Distance Calculation**:
  - Calculates distance between renter and owner locations
  - Uses Haversine formula for accurate km distance
  - Requires both users to have location set in profile

- **Delivery Fee Calculation**:
  - Formula: `Rp 5,000 per 2km` (rounded up)
  - Example: 3.5 km → 2 units → Rp 10,000
  - Example: 5 km → 3 units → Rp 15,000

- **Price Breakdown**:
  - Product rental subtotal (days × price per day)
  - Delivery fee (if delivery method selected)
  - Total price

#### UI Components:
```dart
// Radio buttons for delivery method selection
- Pickup: Shows "Self Pickup" with description
- Delivery: Shows delivery fee and distance when location available

// Distance display
"📍 Distance: 3.5 km • Delivery fee: Rp 10.000"

// Price breakdown card
Product Subtotal: Rp 50,000
Delivery Fee: Rp 10,000
Total: Rp 60,000
```

### 2. Owner Booking Management Screen
**Location**: `lib/features/booking/presentation/screens/owner_booking_management_screen.dart`

#### Features:
- **View all booking requests** for products owned by current user
- **Tab-based filtering** by status:
  - All bookings
  - Pending (awaiting confirmation)
  - Confirmed (accepted by owner)
  - Active (rental in progress)
  - Completed (rental finished)

- **Booking Status Workflow**:
  ```
  Pending → Confirmed → Active → Completed
              ↓
          Cancelled
  ```

- **Action Buttons per Status**:
  - **Pending**: Accept or Reject
  - **Confirmed**: Start Rental
  - **Active**: Mark as Completed
  - **Completed**: View only

#### UI Features:
- **Booking card displays**:
  - Status badge with color coding
  - Product image and name
  - Renter name
  - Rental period and duration
  - Delivery method (pickup/delivery icon)
  - Distance and delivery fee (if delivery)
  - Total price
  - Action buttons

- **Status Colors**:
  - Pending: Orange
  - Confirmed: Blue
  - Active: Green
  - Completed: Grey
  - Cancelled: Red

- **Confirmation Dialogs**:
  - Accept booking
  - Reject booking
  - Start rental
  - Complete rental

## Database Schema

### Bookings Table Additions
```sql
-- New columns
delivery_method delivery_method DEFAULT 'pickup',  -- ENUM: pickup/delivery
delivery_fee DECIMAL(10, 2) DEFAULT 0,             -- Fee in IDR
distance_km DECIMAL(10, 2),                        -- Distance in km
owner_id UUID,                                     -- Product owner ID
renter_address TEXT,                               -- Renter's address
notes TEXT                                         -- Additional notes

-- Trigger: Auto-populate owner_id
CREATE TRIGGER set_booking_owner_id_trigger
  BEFORE INSERT ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION set_booking_owner_id();
```

### Delivery Fee Calculation Function
```sql
CREATE OR REPLACE FUNCTION calculate_delivery_fee(distance_km DECIMAL)
RETURNS DECIMAL AS $$
DECLARE
  base_fee CONSTANT DECIMAL := 5000;
  distance_unit CONSTANT DECIMAL := 2;
  fee DECIMAL;
BEGIN
  IF distance_km IS NULL OR distance_km <= 0 THEN
    RETURN 0;
  END IF;
  
  fee := CEIL(distance_km / distance_unit) * base_fee;
  RETURN fee;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

### Bookings with Details View
```sql
CREATE VIEW bookings_with_details AS
SELECT 
  b.*,
  p.name AS product_name,
  p.image_url AS product_image_url,
  p.price_per_day,
  p.owner_id,
  u.full_name AS user_name,
  u.location AS renter_location
FROM bookings b
JOIN products p ON b.product_id = p.id
JOIN profiles u ON b.user_id = u.id;
```

## Model Updates

### DeliveryMethod Enum
```dart
enum DeliveryMethod {
  pickup('pickup', 'Self Pickup', 'Renter picks up from owner'),
  delivery('delivery', 'Delivery', 'Owner delivers to renter');

  final String value;
  final String label;
  final String description;
}
```

### BookingStatus Enum
```dart
enum BookingStatus {
  pending('pending', 'Pending', 'Waiting for owner confirmation'),
  confirmed('confirmed', 'Confirmed', 'Owner accepted, ready to start'),
  active('active', 'Active', 'Currently renting'),
  completed('completed', 'Completed', 'Rental finished'),
  cancelled('cancelled', 'Cancelled', 'Booking cancelled');

  final String value;
  final String label;
  final String description;
}
```

### Booking Model Fields
```dart
class Booking {
  final DeliveryMethod deliveryMethod;
  final double deliveryFee;
  final double? distanceKm;
  final String? ownerId;
  final String? renterAddress;
  final String? notes;

  // Calculated getters
  double get productSubtotal => totalPrice - deliveryFee;
  String get formattedDeliveryFee => 'Rp ...';
  
  // Static method
  static double calculateDeliveryFee(double distanceKm) {
    if (distanceKm <= 0) return 0;
    const baseFee = 5000.0;
    const distanceUnit = 2.0;
    return (distanceKm / distanceUnit).ceil() * baseFee;
  }
}
```

### BookingWithProduct Model
```dart
class BookingWithProduct {
  final Booking booking;
  final Product product;
  final String userName;  // Renter's name

  // Convenience getters
  DeliveryMethod get deliveryMethod;
  double get deliveryFee;
  double? get distanceKm;
  String get formattedDeliveryFee;
}
```

## Repository Methods

### BookingRepository
```dart
// Create booking with delivery info
Future<Booking> createBooking({
  required String productId,
  required DateTime startDate,
  required DateTime endDate,
  required double totalPrice,
  // Auto-added by UI: delivery fields
});

// Get bookings for product owner
Future<List<BookingWithProduct>> getOwnerBookings(String ownerId);

// Update booking status
Future<Booking> updateBookingStatus({
  required String bookingId,
  required BookingStatus status,
});
```

## LocationService Integration

### Distance Calculation
```dart
// Calculate distance between two LatLng points
Future<double> calculateDistance(LatLng start, LatLng end);

// Uses Haversine formula:
// d = R × c
// where R = Earth radius (6371 km)
//       c = 2 × atan2(√a, √(1-a))
//       a = sin²(Δlat/2) + cos(lat1) × cos(lat2) × sin²(Δlon/2)
```

## Routing

### Routes Added
```dart
// User creates booking
'/bookings/new?productId={id}' → BookingFormScreen

// Owner manages bookings
'/owner/bookings' → OwnerBookingManagementScreen

// View booking details
'/bookings/:id' → BookingDetailScreen
```

## Usage Flow

### User Booking Flow
1. User browses products and selects one
2. User clicks "Book Now" button
3. BookingFormScreen opens with product details
4. User selects date range
5. User selects delivery method:
   - If Delivery: Distance and fee auto-calculated
   - If Pickup: No additional fee
6. User adds optional notes
7. User reviews price breakdown
8. User submits booking
9. Booking created with status: Pending

### Owner Management Flow
1. Owner navigates to `/owner/bookings`
2. OwnerBookingManagementScreen shows all bookings
3. Owner filters by status tabs
4. For **Pending** bookings:
   - Owner reviews booking details
   - Owner clicks Accept or Reject
   - If accepted: Status → Confirmed
   - If rejected: Status → Cancelled
5. For **Confirmed** bookings:
   - Owner clicks "Start Rental"
   - Status → Active
6. For **Active** bookings:
   - Owner clicks "Mark as Completed"
   - Status → Completed

## Validation

### Booking Form Validation
- ✅ Start date required
- ✅ End date required
- ✅ End date must be after start date
- ✅ Product must be available for date range
- ✅ Location required for delivery method
- ✅ Notes max 500 characters

### Location Validation
```dart
// Check if user has location set
if (deliveryMethod == DeliveryMethod.delivery) {
  if (renterLocation == null || ownerLocation == null) {
    // Show error: "Location required for delivery"
  }
}
```

## Error Handling

### BookingFormScreen
```dart
// Loading states
- Loading product data
- Loading user profile
- Loading owner profile
- Calculating distance
- Submitting booking

// Error states
- Product not found
- Failed to load profile
- Failed to calculate distance
- Failed to create booking
```

### OwnerBookingManagementScreen
```dart
// Loading states
- Loading bookings
- Refreshing bookings

// Error states
- Failed to load bookings
- Failed to update status
- No bookings available
```

## Testing Checklist

### Booking Creation
- [ ] Create booking with pickup method
- [ ] Create booking with delivery method
- [ ] Verify distance calculation
- [ ] Verify delivery fee calculation
- [ ] Verify price breakdown
- [ ] Submit booking successfully

### Owner Management
- [ ] View all bookings
- [ ] Filter by status (pending/confirmed/active/completed)
- [ ] Accept pending booking
- [ ] Reject pending booking
- [ ] Start confirmed rental
- [ ] Complete active rental
- [ ] View delivery details
- [ ] Refresh booking list

### Edge Cases
- [ ] User without location selects delivery
- [ ] Product with no owner location
- [ ] Distance calculation fails
- [ ] Duplicate booking submission
- [ ] Booking unavailable dates

## Future Enhancements

### Priority 1
- [ ] Push notifications for booking status changes
- [ ] Email notifications
- [ ] In-app notifications

### Priority 2
- [ ] Review system after completed rental
- [ ] Rating system for owners and renters
- [ ] Chat between owner and renter

### Priority 3
- [ ] Payment integration (midtrans/xendit)
- [ ] Automatic booking confirmation
- [ ] Calendar view for booking dates
- [ ] Delivery tracking
- [ ] Insurance options

## File Structure

```
lib/features/booking/
├── data/
│   └── repositories/
│       └── booking_repository.dart          # CRUD operations, getOwnerBookings
├── domain/
│   └── models/
│       ├── booking.dart                     # DeliveryMethod, calculateDeliveryFee
│       └── booking_with_product.dart        # Extended model with user/product info
└── presentation/
    └── screens/
        ├── booking_form_screen.dart         # Create booking with delivery method
        ├── owner_booking_management_screen.dart  # Owner workflow management
        ├── booking_detail_screen.dart       # View booking details
        ├── booking_list_screen.dart         # User's bookings
        └── booking_history_screen.dart      # Past bookings
```

## SQL Migration

Run this SQL file on your Supabase project:
```
supabase_booking_delivery_system.sql
```

This includes:
- delivery_method ENUM type
- New columns on bookings table
- calculate_delivery_fee() function
- set_booking_owner_id() trigger
- bookings_with_details view
- get_owner_bookings() RPC function
- Updated RLS policies

## Key Dependencies

```yaml
dependencies:
  flutter_riverpod: ^2.4.0      # State management
  go_router: ^12.0.0             # Routing
  cached_network_image: ^3.3.0   # Image caching
  geolocator: ^10.1.0            # Location services
  geocoding: ^2.1.1              # Address conversion
  supabase_flutter: ^2.0.0       # Backend
```

## Delivery Fee Calculation Examples

| Distance (km) | Units (ceil) | Base Fee | Total Fee |
|--------------|--------------|----------|-----------|
| 0.5          | 1            | Rp 5,000 | Rp 5,000  |
| 2.0          | 1            | Rp 5,000 | Rp 5,000  |
| 2.1          | 2            | Rp 5,000 | Rp 10,000 |
| 4.0          | 2            | Rp 5,000 | Rp 10,000 |
| 5.8          | 3            | Rp 5,000 | Rp 15,000 |
| 10.0         | 5            | Rp 5,000 | Rp 25,000 |

## Clean Code Principles Applied

1. **Single Responsibility**: Each screen/component has one clear purpose
2. **Separation of Concerns**: UI, business logic, data layers separated
3. **DRY**: Reusable methods (calculateDeliveryFee in both Dart and SQL)
4. **Meaningful Names**: Clear method and variable names
5. **Error Handling**: Comprehensive try-catch with user feedback
6. **Loading States**: User feedback during async operations
7. **Validation**: Input validation before submission
8. **Documentation**: Inline comments and comprehensive docs
9. **Type Safety**: Enums for status and delivery method
10. **Immutability**: Const constructors where possible
