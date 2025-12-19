import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/core/constants/app_strings.dart';
import 'package:rentlens/features/auth/controllers/auth_controller.dart';
import 'package:rentlens/features/auth/domain/models/auth_state.dart';
import 'package:rentlens/features/auth/presentation/screens/login_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Manual registration (NO Supabase Auth - creates user in users table)
    final success = await ref.read(authStateProvider.notifier).signUp(
          username: _usernameController.text,
          password: _passwordController.text,
          fullName: _usernameController.text, // Use username as default
          email:
              _emailController.text.isNotEmpty ? _emailController.text : null,
        );

    if (success && mounted) {
      // Redirect to login screen immediately
      context.goNamed('login');
      
      // Show success message after navigation
      // Use Future.delayed to ensure navigation completes first
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registrasi berhasil! Silakan login dengan akun Anda.'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final authState = authAsync.value;

    // Listen to auth state changes for error feedback only
    ref.listen<AsyncValue<AuthState>>(
      authStateProvider,
      (previous, next) {
        final nextState = next.value;

        // Show error feedback
        if (nextState?.hasError == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(nextState!.error!),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );

    final isLoading = authState?.isInitializing ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: isLoading
              ? null
              : () {
                  // Navigate back to login screen via GoRouter
                  context.goNamed('login');
                },
        ),
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
                AppStrings.registerTitle,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.registerSubtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),

              const SizedBox(height: 32),

              // Username (required, PRIMARY identifier)
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Masukkan username Anda',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
                enabled: !isLoading,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Username harus diisi';
                  }
                  if (value!.length < 3) {
                    return 'Username minimal 3 karakter';
                  }
                  if (value.length > 30) {
                    return 'Username maksimal 30 karakter';
                  }
                  // Only allow alphanumeric and underscore
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                    return 'Username hanya boleh huruf, angka, dan garis bawah';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Email (OPTIONAL - no validation needed)
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Masukkan email Anda',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
                // NO validator - email is completely optional
              ),

              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: AppStrings.password,
                  hintText: 'Buat kata sandi',
                  prefixIcon: const Icon(Icons.lock_outline),
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
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Register button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleRegister,
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
                          AppStrings.register,
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

              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppStrings.alreadyHaveAccount,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  InkWell(
                    onTap: isLoading
                        ? null
                        : () {
                            // Navigate to login screen via GoRouter
                            context.goNamed('login');
                          },
                    child: Text(
                      AppStrings.loginNow,
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
