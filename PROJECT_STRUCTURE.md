# RentLens - Flutter Project Structure

## Feature-First Architecture

```
lib/
├── main.dart                           # App entry point
│
├── core/                               # Core functionality
│   ├── config/
│   │   ├── env_config.dart            # Environment configuration
│   │   ├── supabase_config.dart       # Supabase client initialization
│   │   └── router_config.dart         # GoRouter configuration
│   ├── theme/
│   │   ├── app_theme.dart             # App theme configuration
│   │   └── app_colors.dart            # Color constants
│   ├── constants/
│   │   └── app_constants.dart         # App-wide constants
│   └── utils/
│       ├── date_formatter.dart        # Date formatting utilities
│       └── validators.dart            # Input validators
│
├── features/                           # Feature modules
│   ├── auth/                          # Authentication feature
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── user_model.dart
│   │   │   └── repositories/
│   │   │       └── auth_repository.dart
│   │   ├── presentation/
│   │   │   ├── providers/
│   │   │   │   └── auth_provider.dart
│   │   │   ├── screens/
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── register_screen.dart
│   │   │   │   └── profile_screen.dart
│   │   │   └── widgets/
│   │   │       └── auth_form_field.dart
│   │   └── domain/
│   │       └── entities/
│   │           └── user_entity.dart
│   │
│   ├── home/                          # Home feature
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   └── home_screen.dart
│   │   │   └── widgets/
│   │   │       ├── category_filter.dart
│   │   │       └── product_card.dart
│   │   └── providers/
│   │       └── home_provider.dart
│   │
│   ├── products/                      # Products feature
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   └── product_model.dart
│   │   │   └── repositories/
│   │   │       └── product_repository.dart
│   │   ├── presentation/
│   │   │   ├── providers/
│   │   │   │   └── product_provider.dart
│   │   │   ├── screens/
│   │   │   │   ├── product_list_screen.dart
│   │   │   │   └── product_detail_screen.dart
│   │   │   └── widgets/
│   │   │       └── product_image.dart
│   │   └── domain/
│   │       └── entities/
│   │           └── product_entity.dart
│   │
│   └── booking/                       # Booking feature
│       ├── data/
│       │   ├── models/
│       │   │   └── booking_model.dart
│       │   └── repositories/
│       │       └── booking_repository.dart
│       ├── presentation/
│       │   ├── providers/
│       │   │   └── booking_provider.dart
│       │   ├── screens/
│       │   │   ├── booking_form_screen.dart
│       │   │   ├── booking_list_screen.dart
│       │   │   └── booking_detail_screen.dart
│       │   └── widgets/
│       │       ├── date_picker_widget.dart
│       │       └── booking_status_badge.dart
│       └── domain/
│           └── entities/
│               └── booking_entity.dart
│
└── shared/                            # Shared widgets and utilities
    ├── widgets/
    │   ├── custom_button.dart
    │   ├── custom_text_field.dart
    │   ├── loading_indicator.dart
    │   └── error_widget.dart
    └── extensions/
        ├── context_extensions.dart
        └── string_extensions.dart
```

## Architecture Layers

### Core
Contains app-wide configurations, constants, themes, and utilities.

### Features
Each feature is self-contained with:
- **Data Layer**: Models, repositories, data sources
- **Domain Layer**: Entities, use cases (optional for simple apps)
- **Presentation Layer**: Screens, widgets, providers

### Shared
Reusable widgets and utilities used across multiple features.

## Key Benefits
- **Scalability**: Easy to add new features
- **Maintainability**: Clear separation of concerns
- **Testability**: Each layer can be tested independently
- **Team Collaboration**: Different developers can work on different features
