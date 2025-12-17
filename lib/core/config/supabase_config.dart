import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'env_config.dart';

/// Supabase Client Configuration
class SupabaseConfig {
  static SupabaseClient? _client;

  /// Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
      debug: true, // Set to false in production
    );
    _client = Supabase.instance.client;
  }

  /// Get Supabase client instance
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception(
        'Supabase has not been initialized. Call SupabaseConfig.initialize() first.',
      );
    }
    return _client!;
  }

  /// Check if user is authenticated (using manual auth)
  static Future<bool> get isAuthenticated async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') != null;
  }

  /// Get current user ID from SharedPreferences (manual auth)
  static Future<String?> get currentUserId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }
}
