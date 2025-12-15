# Location-First Product Discovery Migration

## Overview

This migration transforms RentLens from a global product listing with optional nearby filtering to a **location-first discovery system** where products are displayed based on the user's current location by default.

## What Changed

### Before
- Home screen showed all products globally
- "Nearby Products" was a separate optional screen
- Users in Papua could see cameras in Sumatra (impractical for rental)
- Location-based filtering required extra navigation

### After
- Home screen **always** shows location-based products by default
- Products filtered by distance within configurable radius (default: 20km)
- Separate "Nearby Products" screen removed
- Graceful permission handling with fallback UI
- Search and category filters work within location scope

## Architecture Changes

### 1. Enhanced Database RPC (`supabase_location_first_products.sql`)

**New Function:**
```sql
get_nearby_products(
  user_lat DOUBLE PRECISION,
  user_lon DOUBLE PRECISION, 
  radius_km DOUBLE PRECISION DEFAULT 20.0,
  search_text TEXT DEFAULT NULL,
  filter_category TEXT DEFAULT NULL,
  exclude_user_id UUID DEFAULT NULL
)
```

**Features:**
- Haversine distance calculation
- Full-text search within location scope
- Category filtering
- Travel time estimation (60km/h average)
- Automatic sorting by distance

**Migration:**
```bash
# Run in Supabase SQL Editor
psql -f supabase_location_first_products.sql
```

### 2. Location-Aware Product Controller

**File:** `lib/features/products/providers/location_aware_product_provider.dart`

**Key Components:**

```dart
// Unified state with location context
class LocationAwareProductState {
  final List<ProductWithDistance> products;
  final Position? currentPosition;
  final double radiusKm;
  final String searchQuery;
  final ProductCategory? selectedCategory;
  final LocationPermission locationPermission;
  final bool isLoading;
  final String? error;
}

// Single controller replacing dual provider pattern
class LocationAwareProductController extends StateNotifier<LocationAwareProductState> {
  // Auto-initializes location on creation
  // Unified search, filter, and location management
  // Progressive permission flow
}
```

**Providers:**
```dart
// Main state controller
final locationAwareProductControllerProvider = 
  StateNotifierProvider<LocationAwareProductController, LocationAwareProductState>(...);

// Convenience accessors
final nearbyProductsProvider = Provider<List<ProductWithDistance>>(...);
final locationPermissionStatusProvider = Provider<LocationPermission>(...);
final currentRadiusProvider = Provider<double>(...);
```

### 3. Updated Product Repository

**File:** `lib/features/products/data/repositories/product_repository.dart`

**Primary Method:**
```dart
Future<List<ProductWithDistance>> getNearbyProducts({
  required double latitude,
  required double longitude,
  double radiusKm = 20.0,
  String? searchText,
  String? category,
}) async {
  final response = await _supabase.rpc(
    'get_nearby_products',
    params: {
      'user_lat': latitude,
      'user_lon': longitude,
      'radius_km': radiusKm,
      'search_text': searchText,
      'filter_category': category,
    },
  );
  // ... parse ProductWithDistance objects
}
```

**Deprecated:**
```dart
@Deprecated('Use getNearbyProducts() instead - location-first is the default')
Future<List<Product>> getProducts() async { ... }
```

### 4. New Location UI Components

#### a. Permission Banner (`location_permission_banner.dart`)
- Displays when location permission needed/denied
- Educational rationale dialog
- Direct link to app settings
- Dismissible for permanently denied state

#### b. Location Status Header (`location_status_header.dart`)
- Shows current city/location name
- Displays active search radius
- Product count within radius
- Quick actions: refresh location, adjust radius

#### c. No Products Widget (`no_nearby_products_widget.dart`)
- Empty state when no products found
- Progressive radius suggestions (20km → 30km → 50km)
- Refresh action
- Encouraging messaging

#### d. Distance Badge (`product_distance_badge.dart`)
- Visual distance indicator on product cards
- Color-coded:
  - 🟢 Green: < 5km (very close)
  - 🔵 Blue: 5-15km (close)
  - 🟠 Orange: 15-30km (moderate)
  - 🔴 Red: > 30km (far)
- Compact mode for grid layouts

### 5. Refactored Home Screen

**File:** `lib/features/home/presentation/screens/home_screen.dart`

**Key Changes:**

```dart
class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final controller = ref.read(locationAwareProductControllerProvider.notifier);
    final state = ref.watch(locationAwareProductControllerProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Permission banner when needed
          if (!state.hasLocationPermission)
            SliverToBoxAdapter(
              child: LocationPermissionBanner(
                onRequestPermission: () => controller.requestLocationPermission(),
              ),
            ),

          // Location status header
          if (state.hasLocation)
            SliverToBoxAdapter(
              child: LocationStatusHeader(
                location: state.currentPosition!,
                radiusKm: state.radiusKm,
                productCount: state.productCount,
                onRefresh: () => controller.refresh(),
                onAdjustRadius: () => _showRadiusDialog(context, controller, state.radiusKm),
              ),
            ),

          // Search bar (searches within location scope)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: controller.updateSearch,
                decoration: InputDecoration(
                  hintText: 'Cari kamera terdekat...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
          ),

          // Category filter chips
          SliverToBoxAdapter(
            child: _buildCategoryFilter(controller, state),
          ),

          // Products grid with distance badges
          SliverToBoxAdapter(
            child: _buildProductsSection(state, controller, context),
          ),
        ],
      ),
    );
  }
}
```

**Removed:**
- "Nearby Products" button
- Global product listing
- Separate nearby screen navigation

**Added:**
- Location permission flow
- Radius adjustment dialog
- Progressive loading states
- Distance-aware product cards

## Migration Checklist

### Database
- [x] Run `supabase_location_first_products.sql`
- [ ] Verify RPC function works with test coordinates
- [ ] Check indexes on `products.latitude/longitude`

### Backend
- [x] Update ProductRepository to use `getNearbyProducts()` as primary
- [x] Deprecate old `getProducts()` method

### State Management
- [x] Create `LocationAwareProductController`
- [x] Replace dual provider pattern (global + nearby)
- [x] Add location permission state

### UI Components
- [x] Create permission banner
- [x] Create location status header
- [x] Create empty state widget
- [x] Create distance badge component

### Screens
- [x] Refactor home screen for location-first
- [x] Remove nearby products screen
- [x] Update router to remove `/nearby-products` route

### Testing
- [ ] Test with location granted
- [ ] Test with location denied
- [ ] Test with location permanently denied
- [ ] Test search within location scope
- [ ] Test category filter with location
- [ ] Test radius adjustment (10-50km)
- [ ] Test empty state (no products nearby)
- [ ] Test GPS off/unavailable scenarios

## User Flow

### Happy Path
1. User opens app → auto requests location permission
2. Permission granted → fetches nearby products (20km default)
3. Products displayed with distance badges, sorted by proximity
4. User can search/filter within nearby scope
5. User can adjust radius if needed

### Permission Denied Path
1. User opens app → permission denied
2. Permission banner appears with rationale
3. User clicks "Enable Location" → dialog explains benefits
4. User chooses:
   - Grant permission → proceed to happy path
   - Keep denied → banner stays, products not shown
   - Permanently deny → banner shows "Open Settings" link

### No Products Path
1. User in remote area with no nearby cameras
2. Empty state widget shows
3. Suggests increasing radius: "Try 30km radius?"
4. User clicks suggestion → radius updates, searches again
5. Progressive suggestions: 20km → 30km → 40km → 50km

## Performance Considerations

### Database
- **Indexed columns:** `products.latitude`, `products.longitude`
- **RPC optimization:** Uses Haversine formula (accurate for small distances)
- **Query limit:** Returns up to 100 products per request
- **Cached:** Controller caches results until location/filters change

### Mobile
- **Location accuracy:** `LocationAccuracy.high` for best results
- **Update strategy:** Only refresh on manual trigger or radius change
- **Background handling:** Does not track location in background
- **Debouncing:** Search input debounced at 500ms

## Edge Cases Handled

### Location Services
- ✅ GPS disabled → Shows permission banner
- ✅ Mock/fake location → Accepted (for testing)
- ✅ Location timeout → Falls back to last known location
- ✅ No GPS hardware → Shows error with manual location option

### Data Scenarios
- ✅ No internet → Shows cached products (if available)
- ✅ Empty results → Progressive radius suggestions
- ✅ User's own products → Excluded from results
- ✅ Unavailable products → Filtered out

### UI States
- ✅ Loading → Skeleton/spinner with message
- ✅ Error → Retry button with error details
- ✅ Empty → Helpful suggestions
- ✅ Permission flow → Educational dialogs

## Testing Commands

### Database Testing
```sql
-- Test basic location query (Bandung coordinates)
SELECT * FROM get_nearby_products(-6.9175, 107.6191, 20.0);

-- Test with search
SELECT * FROM get_nearby_products(-6.9175, 107.6191, 20.0, 'canon');

-- Test with category filter
SELECT * FROM get_nearby_products(-6.9175, 107.6191, 20.0, NULL, 'DSLR');

-- Test combined filters
SELECT * FROM get_nearby_products(-6.9175, 107.6191, 30.0, 'sony', 'Mirrorless');

-- Performance analysis
EXPLAIN ANALYZE SELECT * FROM get_nearby_products(-6.9175, 107.6191, 20.0);
```

### Flutter Testing
```dart
// Test location-aware provider
final container = ProviderContainer();
final controller = container.read(locationAwareProductControllerProvider.notifier);

// Simulate permission grant
await controller.requestLocationPermission();

// Simulate search
controller.updateSearch('canon');

// Simulate category filter
controller.updateCategory(ProductCategory.dslr);

// Simulate radius change
controller.updateRadius(30.0);

// Check state
final state = container.read(locationAwareProductControllerProvider);
print('Products: ${state.products.length}');
print('Permission: ${state.locationPermission}');
```

## Rollback Plan

If issues arise, rollback is straightforward:

1. **Database:** Keep old `products` table and views unchanged
2. **Code:** Restore previous `home_screen.dart` from git
3. **Route:** Re-add `/nearby-products` route
4. **Provider:** Switch back to `featuredProductsProvider`

The migration is **backward compatible** - old queries still work, new RPC is additive.

## Benefits

### For Users
- ✅ Only see relevant, nearby rental options
- ✅ No confusion from distant products
- ✅ Clear distance information
- ✅ Better trust (location verified)

### For Business
- ✅ Higher conversion (relevant listings)
- ✅ Better user experience
- ✅ Location-aware analytics
- ✅ Foundation for delivery features

### For Developers
- ✅ Cleaner architecture (single source of truth)
- ✅ Easier to maintain (no dual provider logic)
- ✅ Extensible (add geofencing, delivery zones)
- ✅ Better performance (smaller result sets)

## Future Enhancements

- [ ] Save preferred radius per user
- [ ] Geofence notifications (new camera nearby)
- [ ] Delivery zone calculation
- [ ] Multi-location support (work + home)
- [ ] Location history and favorites
- [ ] Heatmap view of product density

## Related Documentation

- [LOCATION_FEATURE_GUIDE.md](LOCATION_FEATURE_GUIDE.md) - Original location feature
- [PRODUCT_FEATURE_SUMMARY.md](PRODUCT_FEATURE_SUMMARY.md) - Product architecture
- [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) - Overall project structure

---

**Migration Date:** December 2024  
**Status:** ✅ Complete  
**Tested:** Pending integration testing
