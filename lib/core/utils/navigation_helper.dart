import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/products/providers/product_provider.dart';
import 'package:rentlens/core/constants/app_strings.dart';

/// Context-Aware Navigation Helper
///
/// Provides reusable navigation patterns that respect user journey context
/// instead of hard-coding destinations.
///
/// **Core Principle:**
/// - Modal actions (forms, dialogs) should ALWAYS pop back to origin
/// - Delete actions should pop detail screens and let parent refresh
/// - Never hard-redirect to Home after user actions
///
/// **Usage Examples:**
/// ```dart
/// // Back button in detail screen
/// NavigationHelper.popOrNavigate(context, fallbackRoute: '/');
///
/// // Delete action
/// await NavigationHelper.deleteAndReturn(
///   context,
///   deleteAction: () => repo.delete(id),
///   fallbackRoute: '/list',
/// );
///
/// // Form submission
/// NavigationHelper.popWithResult(context, result: updatedData);
/// ```
class NavigationHelper {
  /// Pop back to previous screen with optional result.
  /// If navigation stack is empty (deep link), navigate to fallback route.
  ///
  /// **Use Case:** Detail screens, back buttons, cancel actions
  ///
  /// **Parameters:**
  /// - [context]: BuildContext for navigation
  /// - [result]: Optional data to return to parent screen
  /// - [fallbackRoute]: Route to navigate to if can't pop (default: '/')
  ///
  /// **Example:**
  /// ```dart
  /// // Back button in product detail
  /// NavigationHelper.popOrNavigate(context, fallbackRoute: '/');
  ///
  /// // Cancel button in form
  /// NavigationHelper.popOrNavigate(context, result: null);
  /// ```
  static void popOrNavigate(
    BuildContext context, {
    Object? result,
    String fallbackRoute = '/',
  }) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    } else {
      // Deep link scenario - navigate to fallback
      context.go(fallbackRoute);
    }
  }

  /// Pop with result (for modal actions like forms, dialogs).
  /// This is a more explicit version of popOrNavigate for modal contexts.
  ///
  /// **Use Case:** Form submissions, modal dialogs, bottom sheets
  ///
  /// **Example:**
  /// ```dart
  /// // After saving form
  /// if (success) {
  ///   NavigationHelper.popWithResult(context, result: savedData);
  /// }
  /// ```
  static void popWithResult(
    BuildContext context, {
    Object? result,
  }) {
    Navigator.pop(context, result);
  }

  /// Handle delete action: execute deletion, pop detail screen, return result.
  /// Parent screen is responsible for refreshing its list.
  ///
  /// **Use Case:** Delete buttons in detail screens
  ///
  /// **Pattern:**
  /// 1. Execute delete action
  /// 2. Pop detail screen with {'deleted': true} result
  /// 3. Parent receives result and refreshes its data
  ///
  /// **Parameters:**
  /// - [context]: BuildContext for navigation
  /// - [deleteAction]: Async function that performs the deletion
  /// - [fallbackRoute]: Route to navigate if can't pop (optional)
  ///
  /// **Example:**
  /// ```dart
  /// await NavigationHelper.deleteAndReturn(
  ///   context,
  ///   deleteAction: () => productRepo.delete(productId),
  ///   fallbackRoute: '/products/my-listings',
  /// );
  /// ```
  static Future<void> deleteAndReturn(
    BuildContext context, {
    required Future<void> Function() deleteAction,
    String? fallbackRoute,
  }) async {
    await deleteAction();
    popOrNavigate(
      context,
      result: {'deleted': true},
      fallbackRoute: fallbackRoute ?? '/',
    );
  }

  /// Pop multiple screens until reaching a predicate condition.
  /// Useful for nested navigation or multi-step flows.
  ///
  /// **Use Case:** Exiting multi-step wizards, clearing nested modals
  ///
  /// **Example:**
  /// ```dart
  /// // Pop until reaching first route (clear all nested screens)
  /// NavigationHelper.popUntil(context, (route) => route.isFirst);
  /// ```
  static void popUntil(
    BuildContext context,
    bool Function(Route<dynamic>) predicate,
  ) {
    if (Navigator.canPop(context)) {
      Navigator.popUntil(context, predicate);
    }
  }

  /// Replace current route with a new one (without adding to stack).
  /// Use sparingly - only for flows where back button shouldn't work.
  ///
  /// **Use Case:** Post-auth redirect, error recovery flows
  ///
  /// **Example:**
  /// ```dart
  /// // After successful login, replace login screen with home
  /// NavigationHelper.replaceWith(context, route: '/');
  /// ```
  static void replaceWith(
    BuildContext context, {
    required String route,
    Object? extra,
  }) {
    context.pushReplacement(route, extra: extra);
  }

  /// Navigate to a route only if it's different from current location.
  /// Prevents duplicate navigation and stack pollution.
  ///
  /// **Use Case:** Tab switches, dashboard navigation
  ///
  /// **Example:**
  /// ```dart
  /// NavigationHelper.goIfDifferent(context, targetRoute: '/profile');
  /// ```
  static void goIfDifferent(
    BuildContext context, {
    required String targetRoute,
    Object? extra,
  }) {
    final currentLocation = GoRouterState.of(context).matchedLocation;
    if (currentLocation != targetRoute) {
      context.go(targetRoute, extra: extra);
    }
  }

  /// Show confirmation dialog before navigation.
  /// Returns true if user confirmed, false if cancelled.
  ///
  /// **Use Case:** Unsaved changes, destructive actions
  ///
  /// **Example:**
  /// ```dart
  /// final confirmed = await NavigationHelper.confirmNavigation(
  ///   context,
  ///   title: 'Unsaved Changes',
  ///   message: 'You have unsaved changes. Discard them?',
  /// );
  /// if (confirmed) Navigator.pop(context);
  /// ```
  static Future<bool> confirmNavigation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'No',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Safe navigation that catches and logs exceptions.
  /// Useful for graceful error handling in navigation flows.
  ///
  /// **Example:**
  /// ```dart
  /// NavigationHelper.safeNavigate(
  ///   context,
  ///   action: () => context.push('/complex-route'),
  ///   onError: (e) => showErrorDialog(context, e),
  /// );
  /// ```
  static Future<void> safeNavigate(
    BuildContext context, {
    required Future<void> Function() action,
    void Function(Object error)? onError,
  }) async {
    try {
      await action();
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      onError?.call(e);
    }
  }

  /// Open the product detail page after verifying ownership with the backend.
  /// Shows a modal loading indicator while the ownership check runs.
  /// Returns the result of the pushed route (if any).
  static Future<T?> openProductDetail<T>(
    BuildContext context,
    WidgetRef ref,
    String productId,
  ) async {
    // Show blocking loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Trigger provider and wait for server-validated ownership check
      // Use refresh to force recompute (avoid stale cached results across auth changes)
      final isOwner =
          await ref.refresh(isProductOwnerProvider(productId).future);

      if (!context.mounted) return null;

      // Close loading
      Navigator.of(context).pop();

      // Navigate to product detail - provider result will be cached so UI updates immediately
      final result = await context.push<T>('/products/$productId');
      return result;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }
}
