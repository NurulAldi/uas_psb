import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/features/admin/data/admin_repository.dart';
import 'package:rentlens/features/admin/providers/admin_provider.dart';
import 'package:rentlens/features/admin/providers/current_admin_provider.dart';
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
        title: const Text('Ban User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to ban ${user.fullName ?? user.email}?'),
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
            child: const Text('Ban'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final admin = ref.read(currentAdminProvider);
      if (admin == null) return;

      final reason = reasonController.text.trim();
      if (reason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide a reason')),
        );
        return;
      }

      final adminRepo = ref.read(adminRepositoryProvider);
      final success = await adminRepo.banUser(
        userId: user.id,
        adminId: admin.id,
        reason: reason,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User banned successfully')),
          );
          ref.invalidate(allUsersProvider);
          ref.invalidate(bannedUsersProvider);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to ban user')),
          );
        }
      }
    }

    reasonController.dispose();
  }

  Future<void> _unbanUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unban User'),
        content: Text('Are you sure you want to unban $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unban'),
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
            const SnackBar(content: Text('User unbanned successfully')),
          );
          ref.invalidate(allUsersProvider);
          ref.invalidate(bannedUsersProvider);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to unban user')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
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
            ? const Center(child: Text('No users found'))
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
                          color: user.isBanned ? AppColors.error : AppColors.primary,
                        ),
                      ),
                      title: Text(user.fullName ?? 'No Name'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.email),
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
                      title: Text(user['full_name'] ?? 'No Name'),
                      subtitle: Text(user['email']),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                  'Phone', user['phone'] ?? 'N/A'),
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
                                    user['full_name'] ?? user['email'],
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
