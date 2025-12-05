import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment Configuration
///
/// Loads Supabase credentials from .env file
class EnvConfig {
  // Supabase Configuration
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'YOUR_SUPABASE_URL_HERE';

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? 'YOUR_SUPABASE_ANON_KEY_HERE';

  // App Configuration
  static const String appName = 'RentLens';
  static const String appVersion = '1.0.0';

  // Validate configuration
  static bool get isConfigured =>
      supabaseUrl != 'YOUR_SUPABASE_URL_HERE' &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY_HERE' &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;
}
