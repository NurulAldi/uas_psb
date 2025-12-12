# 🗺️ LOCATION-BASED RENTAL FEATURE (20KM RADIUS) - IMPLEMENTATION GUIDE

## 📋 Overview

Fitur ini membatasi rental hanya untuk produk dalam radius **20km** dari lokasi user, memastikan:
- ⚡ Pickup/return lebih cepat (15-30 menit)
- 💰 Biaya logistik lebih rendah
- 🤝 Membangun trust dalam komunitas lokal
- 🎯 User hanya melihat produk yang relevan

---

## ✅ PHASE 1 (MVP) - COMPLETED

### 1. Database Migration ✅

**File:** `supabase_location_feature.sql`

**Changes:**
```sql
-- Added columns to profiles table
- latitude (DOUBLE PRECISION)
- longitude (DOUBLE PRECISION)  
- address (TEXT)
- city (TEXT)
- location_updated_at (TIMESTAMPTZ)

-- Created functions
- calculate_distance_km() - Haversine formula
- get_nearby_products() - RPC for filtering
- get_product_distance() - Single product distance
- update_location_timestamp() - Auto-update trigger

-- Created view
- products_with_location - Join products with owner location

-- Added constraints
- Latitude range: -90 to 90
- Longitude range: -180 to 180
```

**To Apply:**
```bash
# Run in Supabase SQL Editor
psql -U postgres -d rentlens -f supabase_location_feature.sql
```

---

### 2. Flutter Dependencies ✅

**File:** `pubspec.yaml`

**Added:**
```yaml
# Location Services
geolocator: ^11.0.0          # GPS location
geocoding: ^3.0.0            # Address <-> Coordinates
permission_handler: ^11.0.0  # Location permissions
```

**Installation:**
```bash
flutter pub get
```

---

### 3. Core Services ✅

#### **LocationService** (`lib/core/services/location_service.dart`)

**Features:**
- ✅ Get current GPS location
- ✅ Check/request permissions
- ✅ Calculate distance (Haversine)
- ✅ Reverse geocoding (coords → address)
- ✅ Forward geocoding (address → coords)
- ✅ Distance formatting ("1.5 km", "12 km", "500 m")
- ✅ Estimated travel time calculation
- ✅ Validation & error handling

**Usage:**
```dart
final locationService = LocationService();

// Get location
Position? position = await locationService.getCurrentLocation();

// Calculate distance
double distanceKm = locationService.calculateDistance(
  startLat: -6.9175, startLon: 107.6191,
  endLat: -6.2088, endLon: 106.8456,
); // Returns ~120km (Bandung to Jakarta)

// Get address
String address = await locationService.getAddressFromCoordinates(
  latitude: -6.9175,
  longitude: 107.6191,
); // Returns: "Jl. Example, Bandung Kota, Bandung"
```

---

### 4. Domain Models ✅

#### **UserProfile** (Updated)

**File:** `lib/features/auth/domain/models/user_profile.dart`

**New Fields:**
```dart
final double? latitude;
final double? longitude;
final String? address;
final String? city;
final DateTime? locationUpdatedAt;

// Helper getter
bool get hasLocation => latitude != null && longitude != null;
```

#### **ProductWithDistance** (New)

**File:** `lib/features/products/domain/models/product_with_distance.dart`

**Extends Product with:**
```dart
final String ownerName;
final String ownerCity;
final String? ownerAvatar;
final double distanceKm;

// Helper methods
String get formattedDistance;      // "1.5 km"
String get estimatedTravelTime;    // "15 mins"
bool get isWithinRentalRadius;     // true if <= 20km
```

---

### 5. Data Repositories ✅

#### **ProfileRepository** (Updated)

**File:** `lib/features/auth/data/repositories/profile_repository.dart`

**New Methods:**
```dart
// Update user location
Future<void> updateLocation({
  required double latitude,
  required double longitude,
  required String address,
  required String city,
});

// Check if user has location
Future<bool> hasUserSetLocation();
```

#### **ProductRepository** (Updated)

**File:** `lib/features/products/data/repositories/product_repository.dart`

**New Methods:**
```dart
// Get products within radius (calls Supabase RPC)
Future<List<ProductWithDistance>> getNearbyProducts({
  required double userLat,
  required double userLon,
  double radiusKm = 20.0,
  String? category,
});

// Get distance to specific product
Future<double?> getProductDistance({
  required String productId,
  required double userLat,
  required double userLon,
});
```

---

### 6. UI Implementation ✅

#### **Location Setup Page**

**File:** `lib/features/auth/presentation/screens/location_setup_page.dart`

**Features:**
- ✅ First-time location setup flow
- ✅ GPS location fetching with loading state
- ✅ Address & city display
- ✅ Accuracy indicator
- ✅ Error handling (service disabled, permission denied)
- ✅ "Skip" option (with warning)
- ✅ Open settings buttons

**UI Components:**
```dart
// Gradient location icon
// Benefits explanation card
// Location info display (city, address, coords, accuracy)
// Error messages with icons
// Loading states
```

---

## 🚀 USAGE GUIDE

### Step 1: Apply Database Migration

```bash
# Connect to Supabase and run migration
# Via Supabase Dashboard → SQL Editor
# Copy-paste content from supabase_location_feature.sql
```

### Step 2: Update Android Permissions

**File:** `android/app/src/main/AndroidManifest.xml`

```xml
<!-- Add before <application> tag -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

### Step 3: Update iOS Permissions

**File:** `ios/Runner/Info.plist`

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to show nearby rental products within 20km</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>We need your location to show nearby rental products within 20km</string>
```

### Step 4: Add Route (if not already added)

**File:** `lib/core/config/router_config.dart`

```dart
GoRoute(
  path: '/location-setup',
  name: 'location-setup',
  builder: (context, state) {
    final isFirstTime = state.uri.queryParameters['firstTime'] == 'true';
    return LocationSetupPage(isFirstTime: isFirstTime);
  },
),
```

### Step 5: Check Location on Home Screen

**Example Integration:**

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final userProfile = ref.watch(currentUserProfileProvider);
  
  return userProfile.when(
    data: (profile) {
      // Check if user has location
      if (profile == null || !profile.hasLocation) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Please set your location first'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push(
                  '/location-setup?firstTime=true'
                ),
                child: Text('Set Location'),
              ),
            ],
          ),
        );
      }
      
      // User has location, show nearby products
      final nearbyProducts = ref.watch(
        nearbyProductsProvider(
          userLat: profile.latitude!,
          userLon: profile.longitude!,
        ),
      );
      
      return nearbyProducts.when(
        data: (products) => ProductList(products: products),
        loading: () => LoadingIndicator(),
        error: (e, st) => ErrorView(error: e),
      );
    },
    loading: () => LoadingIndicator(),
    error: (e, st) => ErrorView(error: e),
  );
}
```

---

## 📱 USER FLOW

```
┌─────────────────────────────────────┐
│ 1. User opens app                   │
│    ↓                                 │
│ 2. Check if location set            │
│    ↓                                 │
│    ├─ YES → Show nearby products    │
│    └─ NO → Redirect to setup        │
│              ↓                       │
│         3. Location Setup Page      │
│            - Get GPS                 │
│            - Show address            │
│            - Confirm & Save          │
│              ↓                       │
│         4. Return to Home            │
│            - Fetch nearby products   │
│            - Show with distance      │
└─────────────────────────────────────┘
```

---

## 🧪 TESTING CHECKLIST

### Database Tests
- [ ] Migration runs without errors
- [ ] `calculate_distance_km()` returns correct values
- [ ] `get_nearby_products()` filters by radius
- [ ] Indexes improve query performance

### Location Service Tests
- [ ] GPS location fetched successfully
- [ ] Permission requests work correctly
- [ ] Distance calculation is accurate
- [ ] Geocoding returns valid addresses

### UI Tests
- [ ] Location setup page renders correctly
- [ ] GPS button triggers location fetch
- [ ] Error messages display properly
- [ ] Loading states show/hide correctly
- [ ] Save button navigates correctly

### Integration Tests
- [ ] First-time flow redirects to location setup
- [ ] Home screen shows only nearby products
- [ ] Distance badges display correctly
- [ ] Profile update invalidates cache

---

## 🔧 TROUBLESHOOTING

### Issue: "Location services disabled"
**Solution:** Guide user to settings with `openLocationSettings()`

### Issue: "Permission denied"
**Solution:** Show explanation, then `openAppSettings()`

### Issue: "No products found"
**Solutions:**
1. Check if user location is set
2. Verify database has products with owner locations
3. Try increasing radius temporarily for testing
4. Check RLS policies allow access

### Issue: "Distance calculation wrong"
**Solution:** Ensure Haversine formula matches SQL function

---

## 📊 PERFORMANCE CONSIDERATIONS

### Database
- ✅ Indexes on `latitude` and `longitude`
- ✅ View pre-joins products with profiles
- ✅ RPC function for optimized queries

### Flutter
- ✅ Location service singleton
- ✅ Cached network images for avatars
- ✅ Lazy loading for product lists
- ✅ Debounced location updates

---

## 🎯 NEXT STEPS (Phase 2 - Optional)

### Planned Enhancements:
1. **Map View** - Google Maps integration
2. **Custom Radius Filter** - Let users choose 5km, 10km, 20km
3. **Location History** - Track user movement patterns
4. **Estimated Travel Time** - Real-time with traffic data
5. **Route Optimization** - Best pickup route
6. **Meetup Point Suggestions** - Midpoint between users

---

## 📚 REFERENCES

### Haversine Formula
```
a = sin²(Δlat/2) + cos(lat1) × cos(lat2) × sin²(Δlon/2)
c = 2 × atan2(√a, √(1−a))
distance = R × c  (where R = Earth radius = 6371 km)
```

### Geolocator Accuracy Levels
- `lowest`: ±3000m
- `low`: ±1000m
- `medium`: ±100m
- `high`: ±10m
- `best`: ±5m
- `bestForNavigation`: ±3m

---

## ✅ SUMMARY

**Implemented:**
- ✅ Database schema with location columns
- ✅ Haversine distance calculation
- ✅ Supabase RPC functions for filtering
- ✅ LocationService with GPS & geocoding
- ✅ Updated models (UserProfile, ProductWithDistance)
- ✅ Repository methods for location operations
- ✅ Location Setup Page with full UX
- ✅ Platform permissions (Android/iOS)

**Result:**
User dapat melihat dan rent **hanya produk dalam radius 20km**, memastikan proses rental yang lebih cepat, murah, dan efisien! 🎉

---

**Status:** Phase 1 (MVP) ✅ COMPLETE
**Ready for Testing:** Yes
**Production Ready:** After permission setup & migration
