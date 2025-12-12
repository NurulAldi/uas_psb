import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/features/admin/data/admin_repository.dart';
import 'package:rentlens/features/admin/providers/admin_provider.dart';

final adminStatisticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final adminRepo = ref.watch(adminRepositoryProvider);
  return await adminRepo.getStatistics();
});

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatisticsProvider);

    return Scaffold(
      body: statsAsync.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(adminStatisticsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Overview',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Statistics Cards
              _buildStatCard(
                'Total Users',
                stats['total_users'].toString(),
                Icons.people,
                AppColors.primary,
              ),
              const SizedBox(height: 12),

              _buildStatCard(
                'Banned Users',
                stats['banned_users'].toString(),
                Icons.block,
                AppColors.error,
              ),
              const SizedBox(height: 12),

              _buildStatCard(
                'Pending Reports',
                stats['pending_reports'].toString(),
                Icons.report_problem,
                Colors.orange,
              ),
              const SizedBox(height: 12),

              _buildStatCard(
                'Total Reports',
                stats['total_reports'].toString(),
                Icons.report,
                Colors.grey,
              ),
              const SizedBox(height: 12),

              _buildStatCard(
                'Total Products',
                stats['total_products'].toString(),
                Icons.camera_alt,
                Colors.blue,
              ),
              const SizedBox(height: 12),

              _buildStatCard(
                'Total Bookings',
                stats['total_bookings'].toString(),
                Icons.book,
                Colors.green,
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error loading statistics: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(adminStatisticsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
