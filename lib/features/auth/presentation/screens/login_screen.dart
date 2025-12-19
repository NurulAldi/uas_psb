import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/core/constants/app_strings.dart';
import 'package:rentlens/features/auth/controllers/auth_controller.dart';
import 'package:rentlens/features/auth/domain/models/auth_state.dart';
import 'package:rentlens/features/auth/presentation/screens/register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _loginError; // Error message untuk ditampilkan inline

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Clear previous error
    setState(() {
      _loginError = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // Sign in with manual authentication (NO Supabase Auth)
    await ref.read(authControllerProvider.notifier).signIn(
          username,
          password,
        );
  }

  void _showBannedAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            const Text(AppStrings.accountBanned),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.accountBannedMessage,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      AppStrings.contactAdminMessage,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final authState = authAsync.value;

    // Listen to auth state changes for feedback
    ref.listen<AsyncValue<AuthState>>(
      authStateProvider,
      (previous, next) {
        final prevState = previous?.value;
        final nextState = next.value;

        // Show success feedback when transitioning to authenticated
        if (prevState?.status != nextState?.status) {
          if (nextState?.isAuthenticated == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Selamat datang, ${nextState?.user?.fullName ?? nextState?.user?.username}!'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 2),
              ),
            );
            // Router will automatically handle navigation
          }
        }

        // Show error feedback - SET INLINE ERROR instead of SnackBar
        if (nextState?.hasError == true) {
          final error = nextState!.error!;

          // Special handling for banned accounts
          if (error == 'ACCOUNT_BANNED') {
            _showBannedAccountDialog();
          } else {
            // Set inline error instead of SnackBar
            setState(() {
              _loginError = error;
            });
            // Revalidate form to show error
            _formKey.currentState?.validate();
          }
        }
      },
    );

    // Check if loading (AsyncValue.loading) or initializing (first time)
    final isLoading =
        authAsync.isLoading || (authState?.isInitializing ?? false);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),

              // Title
              Text(
                AppStrings.loginWelcomeBack,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.loginSubtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),

              const SizedBox(height: 48),

              // Username field (NO email validation needed)
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Masukkan username Anda',
                  prefixIcon: const Icon(Icons.person_outline),
                  errorText:
                      _loginError != null ? ' ' : null, // Show space for error
                ),
                keyboardType: TextInputType.text,
                enabled: !isLoading,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Username harus diisi';
                  }
                  if (value!.length < 3) {
                    return 'Username minimal 3 karakter';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Password field
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: AppStrings.password,
                  hintText: AppStrings.passwordHint,
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: _loginError, // Show actual error message here
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                enabled: !isLoading,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return AppStrings.passwordRequired;
                  }
                  if (value!.length < 6) {
                    return AppStrings.passwordMinLength;
                  }
                  // Show login error on password field
                  if (_loginError != null) {
                    return null; // Error already shown via errorText
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          AppStrings.login,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      AppStrings.or,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.border)),
                ],
              ),

              const SizedBox(height: 24),

              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppStrings.noAccount,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  InkWell(
                    onTap: isLoading
                        ? null
                        : () {
                            // Navigate to register screen via GoRouter
                            context.goNamed('register');
                          },
                    child: Text(
                      AppStrings.registerNow,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
