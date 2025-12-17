# Navigation Quick Reference Card 🧭

## Import
```dart
import 'package:rentlens/core/utils/navigation_helper.dart';
```

---

## Common Patterns

### 1. Back Button (Detail Screens)
```dart
// ✅ DO THIS
AppBar(
  leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => NavigationHelper.popOrNavigate(
      context,
      fallbackRoute: '/',
    ),
  ),
)
```

### 2. Form Save Button
```dart
// ✅ DO THIS
if (formKey.currentState!.validate()) {
  final saved = await repository.save(data);
  NavigationHelper.popWithResult(
    context,
    result: {'saved': true, 'data': saved},
  );
}
```

### 3. Form Cancel Button
```dart
// ✅ DO THIS
TextButton(
  onPressed: () => NavigationHelper.popOrNavigate(
    context,
    result: null,
  ),
  child: const Text('Cancel'),
)
```

### 4. Delete Button
```dart
// ✅ DO THIS
ElevatedButton(
  onPressed: () async {
    final confirmed = await NavigationHelper.confirmNavigation(
      context,
      title: 'Delete Product',
      message: 'Are you sure?',
    );
    
    if (confirmed) {
      await NavigationHelper.deleteAndReturn(
        context,
        deleteAction: () => repository.delete(id),
        fallbackRoute: '/products',
      );
    }
  },
  child: const Text('Delete'),
)
```

### 5. Parent Screen Navigation
```dart
// ✅ DO THIS - Handle child results
ElevatedButton(
  onPressed: () async {
    final result = await context.push<Map<String, dynamic>>(
      '/products/$id',
    );
    
    // Refresh if child made changes
    if (result?['deleted'] == true || result?['saved'] == true) {
      ref.refresh(productsProvider);
    }
  },
  child: const Text('View Product'),
)
```

### 6. Multi-Step Flow Completion
```dart
// ✅ DO THIS - Exit wizard
NavigationHelper.popUntil(
  context,
  (route) => route.isFirst,
);
```

### 7. Unsaved Changes Guard
```dart
// ✅ DO THIS
Future<bool> _onWillPop() async {
  if (hasUnsavedChanges) {
    return await NavigationHelper.confirmNavigation(
      context,
      title: 'Unsaved Changes',
      message: 'You have unsaved changes. Discard them?',
    );
  }
  return true;
}

// In Scaffold:
WillPopScope(
  onWillPop: _onWillPop,
  child: Scaffold(...),
)
```

### 8. Tab Navigation
```dart
// ✅ DO THIS - Prevent duplicate navigation
BottomNavigationBar(
  onTap: (index) {
    final routes = ['/', '/bookings', '/profile'];
    NavigationHelper.goIfDifferent(
      context,
      targetRoute: routes[index],
    );
  },
)
```

---

## Anti-Patterns ❌

### ❌ NEVER: Hard redirect after action
```dart
// BAD
if (success) {
  context.go('/'); // Loses user context!
}
```

### ❌ NEVER: Navigate in build
```dart
// BAD
@override
Widget build(BuildContext context) {
  if (condition) {
    context.go('/route'); // Causes rebuild loops!
  }
  return Widget();
}
```

### ❌ NEVER: Nested pop + go
```dart
// BAD
Navigator.pop(context);
context.go('/route'); // Stack corruption!
```

### ❌ NEVER: Manual canPop checks
```dart
// BAD - Use NavigationHelper instead
if (Navigator.canPop(context)) {
  Navigator.pop(context);
} else {
  context.go('/fallback');
}

// GOOD
NavigationHelper.popOrNavigate(context, fallbackRoute: '/fallback');
```

---

## Decision Tree

```
Do you need to navigate?
├─ YES → What type of action?
│   ├─ Back button → NavigationHelper.popOrNavigate()
│   ├─ Save form → NavigationHelper.popWithResult()
│   ├─ Cancel form → NavigationHelper.popWithResult(result: null)
│   ├─ Delete item → NavigationHelper.deleteAndReturn()
│   ├─ Exit wizard → NavigationHelper.popUntil()
│   ├─ Tab switch → NavigationHelper.goIfDifferent()
│   └─ Unsaved changes → NavigationHelper.confirmNavigation()
│
└─ NO → Just update state with Riverpod
```

---

## Result Passing Pattern

### Child Screen (Detail/Form)
```dart
// Return result when done
NavigationHelper.popWithResult(
  context,
  result: {
    'action': 'deleted', // or 'saved', 'updated'
    'id': productId,
    'data': productData, // optional
  },
);
```

### Parent Screen (List)
```dart
// Receive and handle result
final result = await context.push<Map<String, dynamic>>('/child');

if (result != null) {
  switch (result['action']) {
    case 'deleted':
      ref.refresh(listProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item deleted')),
      );
      break;
    case 'saved':
      ref.refresh(listProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Changes saved')),
      );
      break;
  }
}
```

---

## Common Use Cases

### Product Detail Screen
```dart
// Back button
NavigationHelper.popOrNavigate(context, fallbackRoute: '/');

// Delete product
await NavigationHelper.deleteAndReturn(
  context,
  deleteAction: () => productRepo.delete(productId),
  fallbackRoute: '/products/my-listings',
);
```

### Edit Profile Screen
```dart
// Save changes
if (valid) {
  await profileRepo.update(data);
  NavigationHelper.popWithResult(
    context,
    result: {'updated': true, 'profile': updatedProfile},
  );
}

// Cancel
NavigationHelper.popOrNavigate(context, result: null);
```

### Payment Screen
```dart
// Payment completed
NavigationHelper.popWithResult(
  context,
  result: {'paymentCompleted': true},
);
```

### Booking Detail Screen
```dart
// Navigate to payment
final result = await context.push<Map>('/payment/$bookingId');
if (result?['paymentCompleted'] == true) {
  ref.refresh(bookingByIdProvider(bookingId));
}
```

---

## Testing Checklist

For each screen with navigation:

- [ ] Back button returns to logical origin
- [ ] Deep link (direct URL) has fallback route
- [ ] Form save pops with result
- [ ] Form cancel pops with null
- [ ] Delete action pops with {'deleted': true}
- [ ] Parent screen handles all result cases
- [ ] No hard `context.go('/')` redirects
- [ ] No navigation in build method
- [ ] Confirmation dialogs for destructive actions

---

## Migration Checklist

When updating an existing screen:

1. [ ] Add import: `import 'package:rentlens/core/utils/navigation_helper.dart';`
2. [ ] Find all `context.go('/')` → Replace with `NavigationHelper.popOrNavigate()`
3. [ ] Find all `Navigator.pop()` in forms → Replace with `popWithResult()`
4. [ ] Find all delete actions → Use `deleteAndReturn()`
5. [ ] Update parent screens to handle results with `await context.push<Map>()`
6. [ ] Test all entry points (Home, Deep Link, etc.)
7. [ ] Remove manual `Navigator.canPop()` checks

---

## Full API Reference

```dart
class NavigationHelper {
  // Pop or navigate to fallback (detail screens, back buttons)
  static void popOrNavigate(
    BuildContext context, {
    Object? result,
    String fallbackRoute = '/',
  });

  // Pop with result (forms, modals)
  static void popWithResult(
    BuildContext context, {
    Object? result,
  });

  // Delete and return (delete actions)
  static Future<void> deleteAndReturn(
    BuildContext context, {
    required Future<void> Function() deleteAction,
    String? fallbackRoute,
  });

  // Pop until predicate (wizards, nested flows)
  static void popUntil(
    BuildContext context,
    bool Function(Route<dynamic>) predicate,
  );

  // Replace current route (post-auth, error recovery)
  static void replaceWith(
    BuildContext context, {
    required String route,
    Object? extra,
  });

  // Navigate only if different (tab switches)
  static void goIfDifferent(
    BuildContext context, {
    required String targetRoute,
    Object? extra,
  });

  // Confirm navigation (unsaved changes)
  static Future<bool> confirmNavigation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'No',
  });

  // Safe navigation (with error handling)
  static Future<void> safeNavigate(
    BuildContext context, {
    required Future<void> Function() action,
    void Function(Object error)? onError,
  });
}
```

---

## Help

**Problem:** User gets sent to Home after action  
**Solution:** Replace `context.go('/')` with `NavigationHelper.popOrNavigate()`

**Problem:** Parent screen doesn't refresh after child changes data  
**Solution:** Use `await context.push<Map>()` and handle result

**Problem:** Deep link causes error when popping  
**Solution:** Always provide `fallbackRoute` parameter

**Problem:** Need confirmation before destructive action  
**Solution:** Use `NavigationHelper.confirmNavigation()`

---

**See Also:**
- `NAVIGATION_ARCHITECTURE.md` - Full architecture guide
- `NAVIGATION_FIX_COMPLETE.md` - Implementation summary
- `lib/core/utils/navigation_helper.dart` - Source code
