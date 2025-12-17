# Navigation Refactor Implementation Plan

## 🎯 Objective
Systematically eliminate hard-coded navigation and implement context-aware patterns across the entire app.

---

## 📊 Current Issues Audit

### Critical Issues Found

#### Issue 1: Edit Profile → Hard Redirect to Home
**File:** `edit_profile_page.dart`
**Problem:** After saving profile, stays on page (GOOD) but comment suggests previous wrong behavior
**Status:** ✅ Already fixed (stays on page)

#### Issue 2: Product Detail → Multiple Hard Redirects
**File:** `product_detail_screen.dart`
**Locations:**
- Line 50: Back button → `context.go('/')`
- Line 105: Error fallback → `context.go('/')`  
- Line 132: Delete success → `context.go('/')`

**Problem:** Ignores entry point (could be from Home, My Listings, Search, etc.)
**Fix Required:** Use `Navigator.pop()` or contextual routing

#### Issue 3: Add/Edit Product → Pop with Result
**File:** `add_product_page.dart`  
**Line:** 192 → `context.pop(true)`
**Status:** ✅ CORRECT - Already using pop with result

#### Issue 4: Payment Screen → Direct Route
**File:** `payment_screen.dart`
**Line:** 272 → `context.go('/bookings/${widget.bookingId}')`
**Problem:** Should return to booking detail, but using `go` instead of checking origin
**Impact:** Medium - Could lose user's browsing context

---

## 🛠️ Fix Priority Matrix

### Priority 1: High Impact, High Frequency
1. **Product Detail Navigation** (multiple entry points, high usage)
2. **Delete Actions** (product, booking - loses context)
3. **Form Submissions** (edit profile, add product)

### Priority 2: Medium Impact, Medium Frequency
4. **Payment Flows** (should return to booking detail)
5. **Booking Management Actions** (confirm, reject, complete)

### Priority 3: Low Impact or Already Correct
6. Auth flows (handled by router)
7. Modal dialogs (mostly using Navigator.pop correctly)

---

## 📐 Implementation Pattern

### Create Reusable Navigation Helper

**File:** `lib/core/utils/navigation_helper.dart`

```dart
/// Context-aware navigation helper
class NavigationHelper {
  /// Pop with result, or navigate to fallback if can't pop
  static void popOrNavigate(
    BuildContext context, {
    Object? result,
    String? fallbackRoute,
  }) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    } else if (fallbackRoute != null) {
      context.go(fallbackRoute);
    }
  }

  /// Pop all modals/dialogs and return with result
  static void popAllAndReturn(
    BuildContext context, {
    Object? result,
    required String fallbackRoute,
  }) {
    // Pop until we reach a major route, then navigate
    if (Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst);
      Navigator.pop(context, result);
    } else {
      context.go(fallbackRoute);
    }
  }

  /// For delete actions: pop detail and invalidate list
  static Future<void> deleteAndReturn(
    BuildContext context, {
    required Future<void> Function() deleteAction,
    String? fallbackRoute,
  }) async {
    await deleteAction();
    popOrNavigate(context, result: {'deleted': true}, fallbackRoute: fallbackRoute);
  }
}
```

---

## 🔧 Screen-by-Screen Fixes

### Fix 1: Product Detail Screen

**Before:**
```dart
// Multiple hard redirects
onPressed: () => context.go('/'),
```

**After:**
```dart
// Context-aware navigation
onPressed: () => NavigationHelper.popOrNavigate(
  context,
  fallbackRoute: '/',
),
```

**Delete Action - Before:**
```dart
await deleteProduct();
context.go('/');
```

**Delete Action - After:**
```dart
await NavigationHelper.deleteAndReturn(
  context,
  deleteAction: () => productRepo.delete(id),
  fallbackRoute: '/products/my-listings',
);
```

---

### Fix 2: Payment Screen

**Before:**
```dart
// Hard navigate to booking detail
context.go('/bookings/${widget.bookingId}');
```

**After:**
```dart
// Pop with success result
Navigator.pop(context, {'paymentUploaded': true});
// Parent booking detail will refresh
```

---

### Fix 3: Booking Management Actions

**Pattern:**
```dart
// Confirm/Reject/Complete actions
Future<void> handleBookingAction() async {
  await performAction();
  // Don't navigate - just show feedback
  ScaffoldMessenger.of(context).showSnackBar(successMessage);
  // Provider will auto-refresh the list
  setState(() {}); // Trigger rebuild if needed
}
```

---

## 📋 File-by-File Changes Required

### Critical Files

1. **product_detail_screen.dart**
   - [ ] Replace 3x `context.go('/')` with `NavigationHelper.popOrNavigate()`
   - [ ] Update delete handler
   - [ ] Add fallback logic

2. **payment_screen.dart**
   - [ ] Change `context.go()` to `Navigator.pop()` with result
   - [ ] Update parent booking detail to handle result

3. **my_listings_page.dart**
   - [ ] Ensure it handles `pop` result from add/edit
   - [ ] Refresh list on return

4. **booking_detail_screen.dart**
   - [ ] Handle payment upload result
   - [ ] Refresh data when modal returns

### Supporting Files

5. **navigation_helper.dart** (NEW)
   - [ ] Create utility class
   - [ ] Add reusable methods
   - [ ] Document usage

---

## 🧪 Testing Plan

### Test Cases

#### TC1: Product Detail Multi-Entry
```
1. Home → Product Detail → Back
   Expected: Return to Home ✓
   
2. My Listings → Product Detail → Back
   Expected: Return to My Listings ✓
   
3. Deep Link → /products/123 → Back
   Expected: Navigate to fallback (Home) ✓
```

#### TC2: Delete Product
```
1. My Listings → Product → Delete
   Expected: Return to My Listings, item removed ✓
   
2. Home → Product → Delete
   Expected: Return to Home, product gone ✓
```

#### TC3: Edit Product
```
1. My Listings → Product → Edit → Save
   Expected: Return to Product Detail (updated) ✓
   
2. Product Detail → Edit → Cancel
   Expected: Return to Product Detail (unchanged) ✓
```

#### TC4: Payment Upload
```
1. Booking Detail → Upload Payment → Success
   Expected: Return to Booking Detail (status updated) ✓
   
2. Booking List → Booking Detail → Upload → Success
   Expected: Return to Booking Detail (refresh) ✓
```

---

## 🔄 Rollout Strategy

### Phase 1: Create Infrastructure (Day 1)
- Create `NavigationHelper` class
- Write unit tests for helper methods
- Document usage in ARCHITECTURE.md

### Phase 2: Fix Critical Paths (Day 2-3)
- Product Detail navigation (all 3 instances)
- Delete product flow
- Test thoroughly

### Phase 3: Payment & Booking (Day 4)
- Payment screen navigation
- Booking management actions
- Test user flows

### Phase 4: Comprehensive Testing (Day 5)
- Run all test cases
- Test on real devices
- Fix edge cases

### Phase 5: Documentation & Review (Day 6)
- Update code comments
- Create migration guide
- Team code review

---

## 📝 Code Review Checklist

Before marking DONE:

- [ ] No `context.go('/')` after CRUD actions
- [ ] All modals use `Navigator.pop(context, result)`
- [ ] Parent screens handle child results
- [ ] Navigation helper is used consistently
- [ ] All test cases pass
- [ ] Edge cases considered (deep links, can't pop, etc.)
- [ ] Documentation updated

---

## 📚 Developer Guidelines

### When to Use What

**Use `Navigator.pop(context, result)`:**
- Modal forms (edit, create)
- Dialogs with actions
- Bottom sheets
- ANY overlay that should return to origin

**Use `context.go(route)`:**
- Root-level tab switches
- Auth state changes (via router redirect)
- Deep link entry points
- Explicit user-initiated navigation (buttons, links)

**Use `NavigationHelper.popOrNavigate()`:**
- Detail screens with back button
- Delete actions
- Any action where origin is uncertain

**NEVER use `context.go('/')` after:**
- Form submission
- Data mutation (create, update, delete)
- User-initiated actions

---

## 🎯 Success Criteria

**Functional:**
- ✅ All user actions return to logical origin
- ✅ No unexpected navigation to Home
- ✅ Deep links handled gracefully

**Technical:**
- ✅ 0 instances of `context.go('/')` after mutations
- ✅ All modals use pop-based navigation
- ✅ Navigation helper used in 100% of detail screens

**UX:**
- ✅ Users don't lose their place
- ✅ Navigation feels predictable
- ✅ Reduced support tickets about "losing context"

---

**Start Date:** December 16, 2025  
**Target Completion:** December 22, 2025  
**Owner:** Development Team
