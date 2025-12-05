# 📋 Quick Reference Card

## 🚀 Commands

```bash
# Initial Setup
flutter pub get                           # Install dependencies
flutter run                               # Run app

# Development
r                                         # Hot reload
R                                         # Hot restart  
q                                         # Quit

# Code Generation
flutter pub run build_runner build        # Generate code
flutter pub run build_runner watch        # Watch mode

# Quality
flutter analyze                           # Check code
flutter format .                          # Format code
flutter test                              # Run tests

# Build
flutter build apk --release               # Android APK
flutter build ios --release               # iOS build
```

## 🗂️ Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point |
| `lib/core/config/env_config.dart` | **Update Supabase credentials here** |
| `lib/core/config/router_config.dart` | Routes & navigation |
| `lib/core/theme/app_colors.dart` | Color customization |
| `pubspec.yaml` | Dependencies |
| `supabase_setup.sql` | Database schema |

## 🎯 Routes

| Route | Screen | Parameters |
|-------|--------|------------|
| `/` | Home | - |
| `/auth/login` | Login | - |
| `/auth/register` | Register | - |
| `/profile` | Profile | - |
| `/products` | Product List | `?category=` |
| `/products/:id` | Product Detail | `:id` |
| `/bookings` | Booking List | - |
| `/bookings/new` | Booking Form | `?productId=` |
| `/bookings/:id` | Booking Detail | `:id` |

## 📊 Database Tables

```sql
profiles        # User profiles (id, email, full_name, phone, avatar_url)
products        # Camera products (id, name, category, price_per_day, etc.)
bookings        # Rental bookings (id, user_id, product_id, dates, status)
```

## 🎨 Product Categories

- `DSLR`
- `Mirrorless`
- `Drone`
- `Lens`

## 📱 Booking Status

- `pending` 🟡
- `confirmed` 🔵
- `active` 🟢
- `completed` ⚪
- `cancelled` 🔴

## 🔧 Supabase Setup

1. **Create Project:** https://supabase.com
2. **Run SQL:** Copy `supabase_setup.sql` → SQL Editor → Run
3. **Get Credentials:** Settings → API
   - Project URL
   - anon/public key
4. **Update Config:** `lib/core/config/env_config.dart`

## 📂 Project Structure

```
lib/
├── core/               # Config, theme, constants
├── features/           # Business features
│   ├── auth/          # Login, register, profile
│   ├── home/          # Dashboard
│   ├── products/      # Product catalog
│   └── booking/       # Rental bookings
└── shared/            # Reusable widgets
```

## 💡 Quick Tips

### Navigation
```dart
context.go('/products');              // Go to route
context.push('/products/123');        // Push route
context.push('/products?category=DSLR'); // With query
```

### Supabase Client
```dart
import 'package:rentlens/core/config/supabase_config.dart';

final client = SupabaseConfig.client;
final user = SupabaseConfig.currentUser;
final isAuth = SupabaseConfig.isAuthenticated;
```

### Theme Colors
```dart
import 'package:rentlens/core/theme/app_colors.dart';

AppColors.primary
AppColors.secondary
AppColors.statusConfirmed
```

### Constants
```dart
import 'package:rentlens/core/constants/app_constants.dart';

AppConstants.productCategories
AppConstants.bookingStatuses
AppConstants.dateFormat
```

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| Import errors | `flutter pub get` |
| Build errors | `flutter clean && flutter pub get` |
| Supabase error | Check credentials in `env_config.dart` |
| Hot reload not working | Press `R` for hot restart |

## 📚 Dependencies

```yaml
# State Management
flutter_riverpod: ^2.5.1

# Backend
supabase_flutter: ^2.3.4

# Navigation
go_router: ^14.0.2

# UI
google_fonts: ^6.1.0
cached_network_image: ^3.3.1

# Utils
intl: ^0.19.0
image_picker: ^1.0.7
uuid: ^4.3.3
```

## 🎓 Next Implementation Steps

1. ✅ Run `flutter pub get`
2. ✅ Configure Supabase credentials
3. ✅ Run the app
4. ⏳ Create `auth_repository.dart`
5. ⏳ Create `product_repository.dart`
6. ⏳ Create `booking_repository.dart`
7. ⏳ Implement Riverpod providers
8. ⏳ Connect UI to backend

## 📞 Resources

- Flutter: https://docs.flutter.dev
- Supabase: https://supabase.com/docs
- Riverpod: https://riverpod.dev
- GoRouter: https://pub.dev/packages/go_router

---

**Keep this card handy during development! 📌**
