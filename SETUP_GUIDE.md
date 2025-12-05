# 🚀 Quick Setup Guide

## Step-by-Step Setup for RentLens Flutter Project

### 1️⃣ Install Flutter Packages

Open terminal in the project directory and run:

```bash
flutter pub get
```

### 2️⃣ Configure Supabase Credentials

**Option A: Update env_config.dart directly (for development)**

Edit `lib/core/config/env_config.dart`:

```dart
static const String supabaseUrl = 'https://your-project-id.supabase.co';
static const String supabaseAnonKey = 'your-anon-key-here';
```

**Where to find these values:**
1. Go to [supabase.com](https://supabase.com) and open your project
2. Click **Settings** → **API**
3. Copy:
   - **Project URL** → Use as `supabaseUrl`
   - **anon/public key** → Use as `supabaseAnonKey`

### 3️⃣ Setup Database

1. Open Supabase Dashboard → **SQL Editor**
2. Copy the entire content from `supabase_setup.sql`
3. Paste and click **Run**
4. Verify tables created: Go to **Table Editor** and check for `profiles`, `products`, `bookings`

### 4️⃣ Run the Application

```bash
flutter run
```

**Select your target device:**
- Press `1` for Chrome (web)
- Press `2` for Android emulator
- Press `3` for iOS simulator (Mac only)

### 5️⃣ Test the App

The app will start with placeholder data. You should see:
- ✅ Login screen (initial screen)
- ✅ Can navigate to Register
- ✅ After "login", see Home screen with categories
- ✅ Browse products by category
- ✅ View product details
- ✅ Create bookings
- ✅ View booking history

## 🎯 Next Steps

### Connect to Real Supabase Data

The current implementation uses placeholder UI. To connect to real data:

1. **Implement Auth Repository** (`features/auth/data/repositories/auth_repository.dart`)
2. **Implement Product Repository** (`features/products/data/repositories/product_repository.dart`)
3. **Implement Booking Repository** (`features/booking/data/repositories/booking_repository.dart`)

### Example: Auth Repository Implementation

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rentlens/core/config/supabase_config.dart';

class AuthRepository {
  final _supabase = SupabaseConfig.client;

  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp(String email, String password, String fullName) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
```

## 🔧 Troubleshooting

### Error: "Target of URI doesn't exist"

This is normal before running `flutter pub get`. Run:
```bash
flutter pub get
```

### Error: "Supabase has not been initialized"

Make sure you've updated the Supabase credentials in `env_config.dart`.

### App crashes on startup

Check that:
1. ✅ Flutter SDK is installed correctly
2. ✅ Supabase credentials are valid
3. ✅ Database tables are created

### Build errors

Try cleaning and rebuilding:
```bash
flutter clean
flutter pub get
flutter run
```

## 📱 Hot Reload

While the app is running, you can make changes and press:
- `r` - Hot reload (fast)
- `R` - Hot restart (slower but full restart)
- `q` - Quit

## 🎨 Customization

### Change App Name
Edit `pubspec.yaml`:
```yaml
name: your_app_name
```

### Change Colors
Edit `lib/core/theme/app_colors.dart`

### Change Theme
Edit `lib/core/theme/app_theme.dart`

### Add New Routes
Edit `lib/core/config/router_config.dart`

## 📚 Useful Commands

```bash
# Install dependencies
flutter pub get

# Run app
flutter run

# Build APK (Android)
flutter build apk --release

# Build for iOS
flutter build ios --release

# Generate code (Riverpod)
flutter pub run build_runner build --delete-conflicting-outputs

# Check for issues
flutter analyze

# Format code
flutter format .

# Run tests
flutter test
```

## 🆘 Need Help?

- Flutter Documentation: https://docs.flutter.dev
- Supabase Documentation: https://supabase.com/docs
- Riverpod Documentation: https://riverpod.dev
- GoRouter Documentation: https://pub.dev/packages/go_router

## ✅ Checklist

Before you start development:

- [ ] Flutter SDK installed and working
- [ ] Supabase project created
- [ ] Database tables created using SQL script
- [ ] Supabase credentials configured in `env_config.dart`
- [ ] Dependencies installed (`flutter pub get`)
- [ ] App runs successfully (`flutter run`)
- [ ] Can navigate between screens
- [ ] Ready to implement real data fetching

---

**Happy Coding! 🎉**
