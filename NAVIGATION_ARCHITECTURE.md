# Navigation Architecture & Rules

## 🎯 Core Principle

**Context-Aware Navigation**: Every user action should return the user to a logical, predictable location based on their journey, NOT to a hard-coded default route.

---

## 📋 Navigation Patterns

### Pattern 1: Modal Actions (Create/Edit/Update)
**Use Case:** Forms, dialogs, bottom sheets opened AS OVERLAYS

**Navigation Method:** `context.push()` or `Navigator.push()`

**Post-Action Behavior:**
- ✅ **Success:** Pop with result → `Navigator.pop(context, result)`
- ✅ **Cancel:** Pop without result → `Navigator.pop(context)`
- ❌ **NEVER:** `context.go('/')` after success

**Example Screens:**
- Edit Profile
- Add/Edit Product
- Booking Form
- Payment Upload

**Rationale:** Modal overlays should ALWAYS return to their origin screen, not hijack the navigation stack.

---

### Pattern 2: Flow Completion (Multi-Step Processes)
**Use Case:** Wizards, onboarding, checkout flows

**Navigation Method:** Progressive `context.push()` through steps

**Post-Action Behavior:**
- ✅ **Success:** Pop ALL intermediate screens → `Navigator.popUntil()` or `context.go(targetRoute)`
- ✅ **Cancel:** Pop back to origin → `Navigator.pop()`

**Example Flows:**
- Auth flow (Register → Profile Setup → Home)
- Booking flow (Product → Booking Form → Payment → Confirmation)

**Rationale:** Multi-step flows have a defined endpoint. Navigate there explicitly, don't assume Home.

---

### Pattern 3: Detail → List Navigation
**Use Case:** User views item details from a list

**Navigation Method:** `context.push('/resource/:id')`

**Post-Action Behavior:**
- ✅ **Delete:** Pop back to list (which will refresh)
- ✅ **Edit:** Stay on detail (refresh data)
- ✅ **Back:** Normal pop

**Example Screens:**
- Product Detail (from Home/My Listings)
- Booking Detail (from Booking List)
- User Profile (from various entry points)

**Rationale:** Deleting an item removes its detail page from the stack. Editing should stay in context.

---

### Pattern 4: Authentication State Changes
**Use Case:** Login, Logout, Session expiry

**Navigation Method:** Global redirect via GoRouter

**Post-Action Behavior:**
- ✅ **Login Success:** Restore intended destination OR go to home
- ✅ **Logout:** Clear stack → `context.go('/auth/login')`
- ✅ **Session Expired:** Clear stack → `context.go('/auth/login')` with message

**Example Actions:**
- Login, Register, Logout

**Rationale:** Auth changes affect global app state. Use router-level redirects, not manual navigation.

---

### Pattern 5: Tab/Bottom Navigation
**Use Case:** Main app sections

**Navigation Method:** Stateful index-based OR named routes

**Post-Action Behavior:**
- ✅ **Tab Switch:** Preserve each tab's stack
- ✅ **Deep Link:** Navigate to correct tab + deep route

**Example:**
- Home, Products, Bookings, Profile tabs

**Rationale:** Each tab is an independent navigation stack.

---

## 🚫 Anti-Patterns (What NOT to Do)

### ❌ Hard Redirect to Home After Success
```dart
// WRONG
if (success) {
  context.go('/'); // ← Ignores user context!
}
```

**Fix:**
```dart
// CORRECT
if (success) {
  Navigator.pop(context, true); // ← Returns to origin
}
```

---

### ❌ Navigation in setState or Build Methods
```dart
// WRONG
void build(BuildContext context) {
  if (someCondition) {
    context.go('/'); // ← Causes rebuild loops!
  }
}
```

**Fix:**
```dart
// CORRECT
void initState() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.go('/');
  });
}
```

---

### ❌ Nested Navigator.pop + context.go
```dart
// WRONG
Navigator.pop(context);
context.go('/'); // ← Redundant and confusing
```

**Fix:**
```dart
// CORRECT - Choose ONE
Navigator.pop(context, result); // For modals
// OR
context.go('/target'); // For flow completions
```

---

### ❌ Ignoring User Entry Point
```dart
// WRONG - Product deleted from anywhere → always go home
if (deleted) {
  context.go('/');
}
```

**Fix:**
```dart
// CORRECT - Pop back to wherever they came from
if (deleted) {
  Navigator.pop(context, {'deleted': true});
  // Parent screen handles refresh
}
```

---

## 🗺️ Route Intent System

### Concept
Pass navigation intent through routes, not hard-code destinations.

### Implementation

**Option 1: Pop with Result**
```dart
// Child screen
final result = await showDialog(...);
Navigator.pop(context, result);

// Parent screen
final result = await context.push('/edit');
if (result == true) {
  // Refresh data
}
```

**Option 2: Query Parameters**
```dart
// Navigate with intent
context.push('/success?returnTo=/profile');

// Success screen reads intent
final returnTo = state.uri.queryParameters['returnTo'] ?? '/';
context.go(returnTo);
```

**Option 3: Extra Data**
```dart
// Navigate with callback
context.push('/form', extra: {
  'onSuccess': () => context.go('/specific-page')
});
```

---

## 📐 Decision Tree

```
┌─────────────────────────────────┐
│   User Triggered Action         │
└──────────┬──────────────────────┘
           │
           ├─► Is it a Modal/Form?
           │   YES → Pattern 1: Pop with result
           │   NO  ↓
           │
           ├─► Is it a Multi-Step Flow?
           │   YES → Pattern 2: Progressive push, explicit end
           │   NO  ↓
           │
           ├─► Is it an Item Detail?
           │   YES → Pattern 3: Pop on delete, stay on edit
           │   NO  ↓
           │
           ├─► Does it Change Auth State?
           │   YES → Pattern 4: Router-level redirect
           │   NO  ↓
           │
           └─► Default: Pop to parent, let parent decide
```

---

## 🛠️ Implementation Guide

### Step 1: Audit Current Navigation
Run these checks:
```bash
# Find all hard redirects to home
grep -r "context.go('/')" lib/

# Find navigation in success handlers
grep -r "if.*success.*context.go" lib/

# Find setState + navigation
grep -r "setState.*Navigator" lib/
```

### Step 2: Categorize Each Screen
For every screen, answer:
1. How is it entered? (push, go, replace)
2. What user actions trigger navigation?
3. Where should each action lead?

### Step 3: Apply Pattern
Match each action to one of the 5 patterns above.

### Step 4: Test User Journeys
```
Journey: Home → Product Detail → Edit Product → Save
Expected: Product Detail (refreshed)
NOT: Home

Journey: My Listings → Add Product → Save
Expected: My Listings (with new item)
NOT: Home

Journey: Profile → Edit Profile → Save
Expected: Profile (updated)
NOT: Home
```

---

## 📊 Screen-by-Screen Rules

### Edit Profile
- **Entry:** `context.push('/edit-profile', extra: profile)`
- **Success:** `Navigator.pop(context, true)` ← Stay in context
- **Cancel:** `Navigator.pop(context, false)`
- **❌ NEVER:** `context.go('/')` after save

### Add/Edit Product
- **Entry:** `context.push('/products/add')` or `/products/:id/edit`
- **Success:** `Navigator.pop(context, product)` ← Return to list
- **Cancel:** `Navigator.pop(context)`
- **❌ NEVER:** `context.go('/products/my-listings')` ← Let parent handle

### Delete Product (from Detail)
- **Action:** `await deleteProduct(id)`
- **Success:** `Navigator.pop(context, {'deleted': true})` ← Pop detail
- **Fallback:** If can't pop, `context.go('/products/my-listings')`

### Booking Form
- **Entry:** `context.push('/booking/form', extra: product)`
- **Success:** `context.go('/bookings/:id')` ← Show booking detail
- **Cancel:** `Navigator.pop(context)`

### Payment Upload
- **Entry:** `context.push('/payment/:bookingId')`
- **Success:** `Navigator.pop(context, true)` ← Return to booking detail
- **❌ NEVER:** `context.go('/bookings')` ← Loses context

### Login/Register
- **Success:** GoRouter redirect based on role
  - Admin → `/admin`
  - User → `/` (home)
- **Explicit navigation ONLY in router redirect logic**

---

## 🧪 Testing Navigation

### Manual Test Cases

**Test 1: Context Preservation**
```
1. Home → Product Detail → Edit → Save
2. Verify: Back on Product Detail (not Home)
```

**Test 2: Multi-Entry Points**
```
Entry A: Home → Product → Delete
Entry B: My Listings → Product → Delete

Both should return to their origin (Home vs My Listings)
```

**Test 3: Deep Link Recovery**
```
1. Deep link to /products/123/edit
2. Save product
3. Should go to /products/123 detail (not Home)
```

---

## 🔄 Migration Strategy

### Phase 1: Fix Critical Paths (Week 1)
- Edit Profile
- Add/Edit Product
- Delete Product
- Booking Form

### Phase 2: Auth Flows (Week 2)
- Login redirect
- Register → Profile setup
- Logout behavior

### Phase 3: Deep Routes (Week 3)
- All detail screens
- All list screens
- Admin screens

### Phase 4: Edge Cases (Week 4)
- Error states
- Network failures
- Permission denials

---

## 📝 Code Review Checklist

Before merging any PR with navigation changes:

- [ ] No `context.go('/')` after CRUD actions
- [ ] Modal actions use `Navigator.pop(context, result)`
- [ ] No navigation in `build()` methods
- [ ] Navigation happens in event handlers, not setState
- [ ] Success feedback (SnackBar) doesn't trigger navigation
- [ ] Parent screens handle child results appropriately
- [ ] Auth state changes use router redirects only
- [ ] Deep link entry points are considered

---

## 🎓 Training Examples

### Example 1: Edit Profile - BEFORE
```dart
Future<void> _saveProfile() async {
  final success = await updateProfile(...);
  if (success) {
    ScaffoldMessenger.of(context).showSnackBar(successMessage);
    context.go('/'); // ❌ WRONG - Loses context
  }
}
```

### Example 1: Edit Profile - AFTER
```dart
Future<void> _saveProfile() async {
  final success = await updateProfile(...);
  if (success) {
    ScaffoldMessenger.of(context).showSnackBar(successMessage);
    Navigator.pop(context, true); // ✅ CORRECT - Returns to origin
  }
}
```

### Example 2: Delete Product - BEFORE
```dart
Future<void> _deleteProduct() async {
  await productRepo.delete(id);
  context.go('/'); // ❌ WRONG - Where did the user come from?
}
```

### Example 2: Delete Product - AFTER
```dart
Future<void> _deleteProduct() async {
  await productRepo.delete(id);
  // Pop the detail screen, parent list will refresh
  if (Navigator.canPop(context)) {
    Navigator.pop(context, {'deleted': true}); // ✅ CORRECT
  } else {
    // Fallback for deep links
    context.go('/products/my-listings');
  }
}
```

---

## 🚀 Success Metrics

Post-implementation, measure:
- User drop-off after successful actions (should be ~0%)
- Support tickets mentioning "lost my place" (should decrease)
- Navigation stack depth in analytics (should be predictable)
- Time to complete common flows (should decrease)

---

**Last Updated:** December 16, 2025  
**Owner:** Development Team  
**Status:** Implementation Required
