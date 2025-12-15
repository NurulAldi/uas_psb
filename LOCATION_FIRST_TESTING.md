# Location-First Discovery - Testing Guide

## Quick Start Testing

### 1. Database Setup

Run the SQL migration in your Supabase SQL Editor:

```bash
# Copy contents of supabase_location_first_products.sql
# Paste into Supabase SQL Editor
# Click "Run"
```

**Verify with test query:**
```sql
-- Replace with your test coordinates (Bandung example)
SELECT 
  name, 
  category, 
  distance_km, 
  estimated_travel_time
FROM get_nearby_products(-6.9175, 107.6191, 20.0)
LIMIT 5;
```

Expected output: Products sorted by distance with travel time.

### 2. Flutter App Testing

#### Scenario 1: Happy Path (Permission Granted)

1. **First Launch:**
   ```
   - App opens
   - Location permission dialog appears
   - Grant "While using the app"
   ```

2. **Expected Behavior:**
   ```
   ✅ Location header appears showing city name
   ✅ Products displayed with distance badges
   ✅ Products sorted by proximity
   ✅ Search bar says "Cari kamera terdekat..."
   ✅ Category chips work (filters within nearby scope)
   ```

3. **Test Actions:**
   - **Search:** Type "canon" → Only nearby Canon cameras shown
   - **Category:** Tap "DSLR" → Only nearby DSLR cameras shown
   - **Radius:** Tap radius icon → Slider appears (5-50km)
   - **Refresh:** Pull to refresh → Re-fetches location and products

#### Scenario 2: Permission Denied

1. **Steps:**
   ```
   - App opens
   - Deny location permission
   ```

2. **Expected Behavior:**
   ```
   ✅ Orange permission banner appears at top
   ✅ Banner says "Izinkan Akses Lokasi"
   ✅ No products shown (or shows error state)
   ✅ Tap "Aktifkan Lokasi" → Dialog explains benefits
   ✅ Can dismiss dialog or grant permission
   ```

3. **Grant Later:**
   ```
   - Tap banner again
   - Grant permission
   - Products load immediately
   ```

#### Scenario 3: Permission Permanently Denied

1. **Steps:**
   ```
   - Deny location 2+ times
   - OR manually disable in system settings
   ```

2. **Expected Behavior:**
   ```
   ✅ Banner changes to "Open Settings" button
   ✅ Tapping opens app settings page
   ✅ User can enable location there
   ✅ Returning to app auto-reloads
   ```

#### Scenario 4: No Nearby Products

1. **Simulate:**
   ```sql
   -- In Supabase, create test user in remote location
   -- Example: Papua coordinates with no products nearby
   SELECT * FROM get_nearby_products(-2.5, 140.7, 20.0);
   -- Should return 0 rows
   ```

2. **Expected UI:**
   ```
   ✅ Empty state widget appears
   ✅ Shows friendly icon and message
   ✅ Suggests "Try 30km radius?"
   ✅ Tapping suggestion expands radius
   ✅ Progressive: 20km → 30km → 40km → 50km
   ```

#### Scenario 5: GPS Disabled

1. **Steps:**
   ```
   - Disable GPS in device settings
   - Keep location permission granted
   ```

2. **Expected Behavior:**
   ```
   ✅ Loading state appears
   ✅ After timeout, error message shown
   ✅ "Turn on GPS" suggestion
   ✅ Retry button available
   ```

### 3. Search & Filter Testing

#### Combined Filters
```
Test: Search + Category + Location
1. Type "sony" in search
2. Select "Mirrorless" category
3. Verify: Only Sony Mirrorless cameras within radius shown
4. Change radius to 30km
5. Verify: More results appear if available
```

#### Edge Cases
```
- Empty search query → Shows all nearby
- Search with no results → Empty state
- Clear category → Shows all nearby
- Clear search → Shows all nearby (with category if set)
```

### 4. Distance Badge Testing

Check products at various distances:

- **< 5km:** Green badge, shows "4.2 km"
- **5-15km:** Blue badge, shows "12.7 km"  
- **15-30km:** Orange badge, shows "23.5 km"
- **> 30km:** Red badge, shows "42.1 km"

Badges should be:
- ✅ Visible on all product cards
- ✅ Positioned top-right
- ✅ Color-coded correctly
- ✅ Rounded to 1 decimal place

### 5. Radius Adjustment Testing

1. **Open Dialog:**
   ```
   - Tap radius value in location header
   - Slider dialog appears
   ```

2. **Test Slider:**
   ```
   - Min: 5km
   - Max: 50km
   - Steps: 5km increments
   - Shows current value in large text
   ```

3. **Apply Changes:**
   ```
   - Drag slider to 30km
   - Tap "Terapkan" (Apply)
   - Loading indicator appears
   - Products re-fetch with new radius
   - Product count updates
   ```

### 6. Performance Testing

#### Load Times
```
Expected benchmarks:
- Initial load: < 2s (with good GPS)
- Search filter: < 500ms (debounced)
- Category filter: < 300ms (instant)
- Radius change: < 2s (new query)
```

#### Database Query Performance
```sql
-- Run EXPLAIN ANALYZE to check performance
EXPLAIN ANALYZE 
SELECT * FROM get_nearby_products(-6.9175, 107.6191, 20.0);

-- Should use indexes on:
-- - products.latitude
-- - products.longitude
-- - products.is_available

-- Query time should be < 100ms for 1000 products
```

### 7. Error Handling Testing

#### Network Errors
```
1. Turn off WiFi/cellular
2. Try to load products
3. Expected: Cached products shown OR error with retry
4. Turn on network
5. Tap retry
6. Products load
```

#### Location Service Errors
```
- Mock location: Should work (for testing)
- Airplane mode: Shows GPS error
- Indoor GPS weak: May take longer, shows loading
- Timeout: Shows error after 30s
```

### 8. State Persistence Testing

```
Test: App backgrounding
1. Search for "canon"
2. Select "DSLR" category  
3. Set radius to 30km
4. Background the app
5. Return to app
Expected: Search, category, radius maintained
```

### 9. Multi-User Testing

#### Test as Owner
```
1. Login as user who owns products
2. Check home screen
3. Expected: Own products NOT shown in nearby list
4. RPC excludes products where owner_id = current user
```

#### Test as Renter
```
1. Login as user with no products
2. Check home screen
3. Expected: All nearby products shown
```

### 10. Regression Testing

Ensure existing features still work:

- ✅ Product detail screen
- ✅ Booking flow
- ✅ "My Listings" page
- ✅ Profile editing
- ✅ Admin dashboard (if admin)

### Common Test Data

#### Sample Coordinates
```
Bandung: -6.9175, 107.6191
Jakarta: -6.2088, 106.8456
Surabaya: -7.2575, 112.7521
Papua: -2.5, 140.7 (for empty state testing)
```

#### Sample Search Terms
```
- "canon" (brand)
- "mirrorless" (category)
- "eos" (model)
- "lens" (accessory)
- "drone" (category)
```

### Debugging Checklist

If location not working:
```
□ Check AndroidManifest.xml has location permissions
□ Check iOS Info.plist has location usage descriptions
□ Verify Geolocator package installed (^11.0.0)
□ Check device GPS is enabled
□ Confirm app has location permission in system settings
□ Try on physical device (emulator GPS can be unreliable)
```

If products not showing:
```
□ Check Supabase RPC function exists
□ Verify products table has latitude/longitude
□ Check user has location permission granted
□ Verify products exist in database within radius
□ Check console for errors
□ Test RPC directly in Supabase SQL editor
```

If search/filter not working:
```
□ Check debouncing (wait 500ms after typing)
□ Verify controller.updateSearch() called
□ Check RPC accepts search_text parameter
□ Verify category enum matches database values
□ Check state updates in Riverpod DevTools
```

### Success Criteria

✅ **Must Have:**
- Location-based products load on first launch
- Distance shown on all product cards
- Search works within location scope
- Category filter works within location scope
- Radius adjustable from 5-50km
- Permission denied handled gracefully
- Empty state shows when no products nearby

✅ **Nice to Have:**
- < 2s load time
- Smooth animations
- Pull-to-refresh works
- State persists across app backgrounding
- Error messages are user-friendly

### Automated Testing (Future)

```dart
// Example integration test
testWidgets('Location-first home screen loads nearby products', (tester) async {
  // Mock location permission granted
  // Mock GPS coordinates
  // Mock Supabase response
  
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();
  
  // Verify permission banner NOT shown
  expect(find.byType(LocationPermissionBanner), findsNothing);
  
  // Verify location header shown
  expect(find.byType(LocationStatusHeader), findsOneWidget);
  
  // Verify products grid shown
  expect(find.byType(GridView), findsOneWidget);
  
  // Verify distance badges present
  expect(find.byType(ProductDistanceBadge), findsWidgets);
});
```

---

**Quick Test Workflow:**

1. ✅ Run SQL migration
2. ✅ Grant location permission
3. ✅ Verify products load with distances
4. ✅ Test search "canon"
5. ✅ Test category "DSLR"
6. ✅ Adjust radius to 30km
7. ✅ Deny permission and re-grant
8. ✅ Check empty state (remote location)

**Estimated Testing Time:** 30-45 minutes for full coverage
