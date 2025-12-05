import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentlens/features/auth/controllers/auth_controller.dart';
import 'package:rentlens/features/auth/presentation/screens/login_screen.dart';
import 'package:rentlens/features/auth/presentation/screens/register_screen.dart';
import 'package:rentlens/features/auth/presentation/screens/edit_profile_page.dart';
import 'package:rentlens/features/home/presentation/screens/home_screen.dart';
import 'package:rentlens/features/products/presentation/screens/product_list_screen.dart';
import 'package:rentlens/features/products/presentation/screens/product_detail_screen.dart';
import 'package:rentlens/features/products/presentation/screens/my_listings_page.dart';
import 'package:rentlens/features/products/presentation/screens/add_product_page.dart';
import 'package:rentlens/features/booking/presentation/screens/booking_form_screen.dart';
import 'package:rentlens/features/booking/presentation/screens/booking_list_screen.dart';
import 'package:rentlens/features/booking/presentation/screens/booking_detail_screen.dart';
import 'package:rentlens/features/booking/presentation/screens/booking_history_screen.dart';
import 'package:rentlens/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Helper class to refresh GoRouter when auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<supabase.AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (event) {
        print('🔄 ROUTER REFRESH: Auth state changed');
        notifyListeners();
      },
    );
  }

  late final StreamSubscription<supabase.AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// GoRouter Configuration Provider with Authentication
final routerProvider = Provider<GoRouter>((ref) {
  // Watch auth state to trigger router refresh on auth changes
  ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: GoRouterRefreshStream(
      ref.read(authControllerProvider.notifier).authStateChanges,
    ),
    redirect: (BuildContext context, GoRouterState state) {
      // Safe access to auth state
      final authState = ref.read(authControllerProvider);

      final isAuthenticated = authState.maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );

      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isLoading = authState.isLoading;

      print('🔀 ROUTER: location=${state.matchedLocation}, '
          'auth=$isAuthenticated, loading=$isLoading');

      // Rule 1: If loading, stay on current page
      if (isLoading) {
        print('🔀 ROUTER: Loading - staying on current page');
        return null;
      }

      // Rule 2: If authenticated, can't go to auth pages
      if (isAuthenticated && isAuthRoute) {
        print('🔀 ROUTER: Authenticated user -> redirect to home');
        return '/';
      }

      // Rule 3: If not authenticated, must go to auth pages (except auth routes)
      if (!isAuthenticated && !isAuthRoute) {
        print('🔀 ROUTER: Not authenticated -> redirect to login');
        return '/auth/login';
      }

      print('🔀 ROUTER: No redirect needed');
      return null;
    },
    routes: [
      // Home Route
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/edit-profile',
        name: 'edit-profile',
        builder: (context, state) {
          final profile = state.extra as dynamic;
          return EditProfilePage(profile: profile);
        },
      ),

      // Product Routes
      GoRoute(
        path: '/products',
        name: 'products',
        builder: (context, state) {
          final category = state.uri.queryParameters['category'];
          return ProductListScreen(category: category);
        },
      ),

      // P2P Marketplace Routes (MUST be before /products/:id)
      GoRoute(
        path: '/products/my-listings',
        name: 'my-listings',
        builder: (context, state) => const MyListingsPage(),
      ),
      GoRoute(
        path: '/products/add',
        name: 'add-product',
        builder: (context, state) => const AddProductPage(),
      ),
      GoRoute(
        path: '/products/:id/edit',
        name: 'edit-product',
        builder: (context, state) {
          final product = state.extra as dynamic;
          return AddProductPage(product: product);
        },
      ),

      // Dynamic product detail route (MUST be last)
      GoRoute(
        path: '/products/:id',
        name: 'product-detail',
        builder: (context, state) {
          final productId = state.pathParameters['id']!;
          return ProductDetailScreen(productId: productId);
        },
      ),

      // Admin Routes
      GoRoute(
        path: '/admin/dashboard',
        name: 'admin-dashboard',
        builder: (context, state) => const AdminDashboardPage(),
      ),

      // Booking Routes
      GoRoute(
        path: '/bookings',
        name: 'bookings',
        builder: (context, state) => const BookingListScreen(),
      ),
      GoRoute(
        path: '/booking-history',
        name: 'booking-history',
        builder: (context, state) => const BookingHistoryScreen(),
      ),
      GoRoute(
        path: '/bookings/new',
        name: 'new-booking',
        builder: (context, state) {
          final productId = state.uri.queryParameters['productId']!;
          return BookingFormScreen(productId: productId);
        },
      ),
      GoRoute(
        path: '/bookings/:id',
        name: 'booking-detail',
        builder: (context, state) {
          final bookingId = state.pathParameters['id']!;
          return BookingDetailScreen(bookingId: bookingId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
