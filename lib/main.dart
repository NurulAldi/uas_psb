import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rentlens/core/config/env_config.dart';
import 'package:rentlens/core/config/router_config.dart';
import 'package:rentlens/core/config/supabase_config.dart';
import 'package:rentlens/core/theme/app_theme.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: '.env');
    print('✅ Environment variables loaded successfully');
  } catch (e) {
    print('⚠️ Warning: Could not load .env file: $e');
  }

  // Initialize Supabase
  try {
    await SupabaseConfig.initialize();
    print('✅ Supabase initialized successfully');
  } catch (e) {
    print('❌ Error initializing Supabase: $e');
    // Continue anyway for development
  }

  // Validate environment configuration
  print('🔍 Checking environment configuration...');
  print('   Supabase URL: ${EnvConfig.supabaseUrl}');
  print('   Supabase Key: ${EnvConfig.supabaseAnonKey.substring(0, 20)}...');

  if (!EnvConfig.isConfigured) {
    print('⚠️ Warning: Environment not configured properly');
    print(
        'Please check your .env file and ensure SUPABASE_URL and SUPABASE_ANON_KEY are set');
  } else {
    print('✅ Environment configured correctly');
  }

  // Run the app with Riverpod
  runApp(const ProviderScope(child: RentLensApp()));
}

class RentLensApp extends ConsumerWidget {
  const RentLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: EnvConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Change to ThemeMode.system for auto theme
      routerConfig: router,
    );
  }
}
