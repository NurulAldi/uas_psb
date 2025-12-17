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
import 'package:rentlens/features/booking/presentation/screens/owner_booking_management_screen.dart';
import 'package:rentlens/features/payment/presentation/screens/payment_screen.dart';
import 'package:rentlens/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:rentlens/features/auth/presentation/screens/public_profile_screen.dart';

/// GoRouter Configuration Provider with Authentication
/// Simplified with single source of truth (authStateProvider)
final routerProvider = Provider<GoRouter>((ref) {
  // Watch auth state to trigger router refresh on auth changes
  final authAsync = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (BuildContext context, GoRouterState state) {
      final auth = authAsync.value;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      final isSplashRoute = state.matchedLocation == '/splash';

      print('🔀 ROUTER REDIRECT: ${state.matchedLocation}');
      print('   authStatus: ${auth?.status}');
      print('   user: ${auth?.user?.username}');
      print('   role: ${auth?.user?.role}');

      // Rule 1: During initialization, show splash screen
      if (auth == null || auth.isInitializing) {
        // FIX: If user is on auth route (login in progress), stay there during loading
        if (isAuthRoute) {
          print('   → Stay on auth page (login in progress)');
          return null;
        }
        if (isSplashRoute) {
          print('   → Stay on splash (initializing)');
          return null;
        }
        print('   → Redirect to /splash (initializing)');
        return '/splash';
      }

      // Rule 2: Unauthenticated users must go to auth pages
      if (auth.isUnauthenticated) {
        if (isAuthRoute) {
          print('   → Allow auth page');
          return null;
        }
        print('   → Redirect to /auth/login (not authenticated)');
        return '/auth/login';
      }

      // Rule 3: Authenticated users - handle role-based routing
      if (auth.isAuthenticated) {
        final isAdmin = auth.user?.role == 'admin';

        // Kick authenticated users out of auth pages
        if (isAuthRoute) {
          final destination = isAdmin ? '/admin' : '/';
          print('   → Redirect to $destination (already authenticated)');
          return destination;
        }

        // Kick authenticated users out of splash
        if (isSplashRoute) {
          final destination = isAdmin ? '/admin' : '/';
          print('   → Redirect to $destination (auth complete)');
          return destination;
        }

        // Admin users can only access admin routes
        if (isAdmin && !isAdminRoute) {
          print('   → Redirect to /admin (admin user accessing user pages)');
          return '/admin';
        }

        // Regular users cannot access admin routes
        if (!isAdmin && isAdminRoute) {
          print('   → Redirect to / (regular user accessing admin)');
          return '/';
        }

        print('   → Allow navigation');
        return null;
      }

      // Fallback: stay on current page
      print('   → No redirect needed');
      return null;
    },
    routes: [
      // Splash Screen (shown during initialization)
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text(
                  'Memuat...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

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

      // Profile Routes (requires authentication)
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        builder: (context, state) {
          final profile = state.extra as dynamic;
          return EditProfilePage(profile: profile);
        },
      ),

      // Public Profile Route (View other users' profiles)
      GoRoute(
        path: '/profile/:userId',
        name: 'public-profile',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return PublicProfileScreen(userId: userId);
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
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),

      // Booking Routes
      GoRoute(
        path: '/bookings',
        name: 'bookings',
        builder: (context, state) => const BookingListScreen(),
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

      // Owner Booking Management Route
      GoRoute(
        path: '/owner/bookings',
        name: 'owner-bookings',
        builder: (context, state) => const OwnerBookingManagementScreen(),
      ),

      // Payment Routes
      GoRoute(
        path: '/payment/:bookingId',
        name: 'payment',
        builder: (context, state) {
          final bookingId = state.pathParameters['bookingId']!;
          return PaymentScreen(bookingId: bookingId);
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
