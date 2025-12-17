import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/core/constants/app_strings.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/features/admin/data/admin_repository.dart';
import 'package:rentlens/features/admin/providers/admin_provider.dart';
import 'package:rentlens/features/auth/controllers/auth_controller.dart';
import 'package:rentlens/features/auth/domain/models/user_profile.dart';

final allUsersProvider =
    FutureProvider.autoDispose<List<UserProfile>>((ref) async {
  final adminRepo = ref.watch(adminRepositoryProvider);
  return await adminRepo.getAllUsers();
});

final bannedUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final adminRepo = ref.watch(adminRepositoryProvider);
  return await adminRepo.getBannedUsers();
});

class UsersManagementScreen extends ConsumerStatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  ConsumerState<UsersManagementScreen> createState() =>
      _UsersManagementScreenState();
}

class _UsersManagementScreenState extends ConsumerState<UsersManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _banUser(UserProfile user) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.banUserTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Are you sure you want to ban ${user.fullName ?? user.email}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter reason for ban',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(AppStrings.ban),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      print('═══════════════════════════════════════════');
      print('🎯 UI: Ban user dialog confirmed');
      print('═══════════════════════════════════════════');

      // Get current logged-in user (should be admin)
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        print('❌ UI ERROR: No user logged in');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Not logged in. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        reasonController.dispose();
        return;
      }

      // Verify user is admin
      if (currentUser.role != 'admin') {
        print('❌ UI ERROR: User is not admin (role: ${currentUser.role})');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Only admins can ban users.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        reasonController.dispose();
        return;
      }

      print('✅ UI: Admin found: ${currentUser.id} (${currentUser.fullName})');

      final reason = reasonController.text.trim();
      if (reason.isEmpty) {
        print('❌ UI ERROR: Reason is empty');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.provideReason)),
          );
        }
        reasonController.dispose();
        return;
      }

      print('✅ UI: Reason provided (${reason.length} chars)');
      print('───────────────────────────────────────────');

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 16),
                Text('Banning user...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      print('🚀 UI: Calling banUser repository method...');
      final adminRepo = ref.read(adminRepositoryProvider);
      final success = await adminRepo.banUser(
        userId: user.id,
        adminId: currentUser.id,
        reason: reason,
      );

      print('───────────────────────────────────────────');
      print('📊 UI: Got result from repository: $success');
      print('═══════════════════════════════════════════');

      // Hide loading
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (mounted) {
        if (success) {
          print('✅ UI: Showing success message');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ ${user.fullName ?? user.email} has been banned successfully!',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          print('🔄 UI: Invalidating providers to refresh data');
          ref.invalidate(allUsersProvider);
          ref.invalidate(bannedUsersProvider);

          print('✅ UI: Ban operation completed successfully!');
        } else {
          print('❌ UI: Showing error message');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Failed to ban user. Check console for details.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          print('❌ UI: Ban operation failed!');
        }
      }
    } else {
      print('⏭️ UI: Ban operation cancelled by user');
    }

    reasonController.dispose();
  }

  Future<void> _unbanUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.unbanUserTitle),
        content: Text('${AppStrings.areYouSureUnban} $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.unban),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final adminRepo = ref.read(adminRepositoryProvider);
      final success = await adminRepo.unbanUser(userId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.userUnbannedSuccessfully)),
          );
          ref.invalidate(allUsersProvider);
          ref.invalidate(bannedUsersProvider);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.failedToUnbanUser)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.userManagement),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Users'),
            Tab(text: 'Banned Users'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllUsersTab(),
          _buildBannedUsersTab(),
        ],
      ),
    );
  }

  Widget _buildAllUsersTab() {
    final usersAsync = ref.watch(allUsersProvider);

    return usersAsync.when(
      data: (users) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allUsersProvider);
        },
        child: users.isEmpty
            ? const Center(child: Text(AppStrings.noUsersFound))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: user.isBanned
                            ? AppColors.error.withOpacity(0.1)
                            : AppColors.primary.withOpacity(0.1),
                        child: Icon(
                          user.isBanned ? Icons.block : Icons.person,
                          color: user.isBanned
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                      title: Text(user
                          .displayName), // Fallback to username if fullName is null
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.email ?? user.username),
                          if (user.phoneNumber != null)
                            Text('Phone: ${user.phoneNumber}'),
                          if (user.isBanned)
                            Text(
                              'BANNED',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      trailing: user.isBanned
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.block, color: Colors.red),
                              onPressed: () => _banUser(user),
                              tooltip: 'Ban User',
                            ),
                    ),
                  );
                },
              ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(allUsersProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannedUsersTab() {
    final bannedAsync = ref.watch(bannedUsersProvider);

    return bannedAsync.when(
      data: (bannedUsers) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bannedUsersProvider);
        },
        child: bannedUsers.isEmpty
            ? const Center(child: Text('No banned users'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: bannedUsers.length,
                itemBuilder: (context, index) {
                  final user = bannedUsers[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.error.withOpacity(0.1),
                        child: Icon(Icons.block, color: AppColors.error),
                      ),
                      title: Text(
                          user['full_name'] ?? user['username'] ?? 'No Name'),
                      subtitle: Text(user['email']),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow('Phone', user['phone'] ?? 'N/A'),
                              _buildInfoRow('Products Count',
                                  user['products_count'].toString()),
                              _buildInfoRow('Bookings Count',
                                  user['bookings_count'].toString()),
                              _buildInfoRow('Reports Against',
                                  user['reports_count'].toString()),
                              _buildInfoRow(
                                  'Banned By', user['banned_by_name'] ?? 'N/A'),
                              _buildInfoRow(
                                  'Reason', user['ban_reason'] ?? 'N/A'),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _unbanUser(
                                    user['id'],
                                    user['full_name'] ??
                                        user['username'] ??
                                        user['email'],
                                  ),
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('Unban User'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(bannedUsersProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
