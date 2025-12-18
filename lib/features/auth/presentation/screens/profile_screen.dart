import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/core/constants/app_strings.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/features/auth/controllers/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    final authState = authAsync.value;
    final user = authState?.user;
    final isLoading = authState?.isInitializing ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profile)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 16),
              Text(
                user?.fullName ?? 'User',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(user?.email ?? user?.username ?? 'No email'),
              const SizedBox(height: 8),
              Text(user?.phoneNumber ?? 'No phone'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final shouldLogout = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text(AppStrings.logout),
                              content: const Text(AppStrings.logoutConfirmation),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text(AppStrings.cancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(AppStrings.logout),
                                ),
                              ],
                            ),
                          );
                          if (shouldLogout == true) {
                            print('\n🔵 PROFILE: Logout confirmed');
                            await ref.read(authControllerProvider.notifier).signOut();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                      : const Text(AppStrings.logout),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
