# RentLens - Camera Rental App

A Flutter-based camera rental application with Supabase backend.

## 📱 Tech Stack

- **Frontend**: Flutter (Material 3)
- **Backend**: Supabase (PostgreSQL + Auth + Storage)
- **State Management**: Riverpod
- **Routing**: GoRouter
- **UI**: Google Fonts
- **Date Formatting**: Intl

## 🏗️ Architecture

This project follows a **Feature-First Architecture** with clean separation of concerns:

```
lib/
├── core/           # App-wide configurations, themes, constants
├── features/       # Feature modules (auth, home, products, booking)
└── shared/         # Reusable widgets and utilities
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.2.0)
- Dart SDK
- Supabase Account
- Android Studio / VS Code

### Setup Instructions

#### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd fix_rentlens
```

#### 2. Install Dependencies

```bash
flutter pub get
```

#### 3. Setup Supabase Database

1. Create a new Supabase project at [supabase.com](https://supabase.com)
2. Go to SQL Editor in Supabase Dashboard
3. Run the SQL script from `supabase_setup.sql`
4. Verify tables are created successfully

#### 4. Configure Environment

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Update `lib/core/config/env_config.dart` with your Supabase credentials:
   ```dart
   static const String supabaseUrl = 'https://your-project.supabase.co';
   static const String supabaseAnonKey = 'your-anon-key-here';
   ```

You can find these values in:
- Supabase Dashboard → Settings → API → Project URL
- Supabase Dashboard → Settings → API → Project API keys (anon/public)

#### 5. Generate Code (if using Riverpod generators)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

#### 6. Run the App

```bash
flutter run
```

## 📂 Project Structure

### Core Layer
- **config/**: Environment, Supabase, and Router configuration
- **theme/**: App theme and color schemes
- **constants/**: App-wide constants

### Features
Each feature contains:
- **data/**: Models and repositories
- **domain/**: Entities and business logic
- **presentation/**: Screens, widgets, and providers

#### Available Features:
- **auth**: Login, Register, Profile
- **home**: Dashboard with categories and featured products
- **products**: Product listing and details
- **booking**: Booking form, list, and details

## 🔑 Key Features

✅ Authentication (Login/Register)  
✅ Product browsing by category  
✅ Product detail view  
✅ Booking system with date selection  
✅ Booking history and status tracking  
✅ User profile management  

## 📱 Screens

### Authentication
- Login Screen (`/auth/login`)
- Register Screen (`/auth/register`)
- Profile Screen (`/profile`)

### Products
- Home Screen (`/`)
- Product List (`/products`)
- Product Detail (`/products/:id`)

### Bookings
- Booking Form (`/bookings/new`)
- Booking List (`/bookings`)
- Booking Detail (`/bookings/:id`)

## 🗄️ Database Schema

### Tables
- **profiles**: User profiles linked to auth.users
- **products**: Camera equipment catalog
- **bookings**: Rental bookings with status tracking

See `supabase_setup.sql` for complete schema.

## 🎨 Customization

### Colors
Edit `lib/core/theme/app_colors.dart` to customize the color scheme.

### Theme
Edit `lib/core/theme/app_theme.dart` to modify Material 3 theme.

### Routing
Edit `lib/core/config/router_config.dart` to add/modify routes.

## 📦 Building for Production

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## 🔧 Development Tools

### Run Tests
```bash
flutter test
```

### Check Code Quality
```bash
flutter analyze
```

### Format Code
```bash
flutter format .
```

## 📝 TODO

- [ ] Implement authentication logic with Supabase Auth
- [ ] Fetch real data from Supabase
- [ ] Add image upload functionality
- [ ] Implement date picker for bookings
- [ ] Add payment proof upload
- [ ] Implement search functionality
- [ ] Add filters for products
- [ ] Implement booking status updates
- [ ] Add push notifications
- [ ] Implement user reviews

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 👥 Authors

- Your Name - Initial work

## 🙏 Acknowledgments

- Flutter Team
- Supabase Team
- Riverpod Community
- Material Design Team
