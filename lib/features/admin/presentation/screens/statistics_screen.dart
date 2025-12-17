import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/features/admin/data/admin_repository.dart';
import 'package:rentlens/features/admin/providers/admin_provider.dart';
import 'package:rentlens/features/products/data/repositories/product_repository.dart';
import 'package:rentlens/features/products/providers/product_provider.dart';

final adminStatisticsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final adminRepo = ref.watch(adminRepositoryProvider);
  return await adminRepo.getStatistics();
});

// Debug provider for testing location view fix
final locationViewTestProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final productRepo = ref.watch(productRepositoryProvider);
  return await productRepo.testLocationView();
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
                stats['total_users']?.toString() ?? '0',
                Icons.people,
                AppColors.primary,
              ),
              const SizedBox(height: 12),

              _buildStatCard(
                'Banned Users',
                stats['banned_users']?.toString() ?? '0',
                Icons.block,
                AppColors.error,
              ),
              const SizedBox(height: 12),

              _buildStatCard(
                'Pending Reports',
                stats['pending_reports']?.toString() ?? '0',
                Icons.report_problem,
                Colors.orange,
              ),
              const SizedBox(height: 12),

              _buildStatCard(
                'Total Reports',
                stats['total_reports']?.toString() ?? '0',
                Icons.report,
                Colors.grey,
              ),

              const SizedBox(height: 32),

              // Debug Tools Section
              const Text(
                'Debug Tools',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),

              _buildDebugCard(
                context,
                ref,
                'Test Location View Fix',
                'Check if products_with_location view is working correctly',
                Icons.location_on,
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

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
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

  Widget _buildDebugCard(
    BuildContext context,
    WidgetRef ref,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showLocationViewTestDialog(context, ref),
        borderRadius: BorderRadius.circular(8),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLocationViewTestDialog(
      BuildContext context, WidgetRef ref) async {
    final testAsync = ref.watch(locationViewTestProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location View Test'),
        content: SizedBox(
          width: double.maxFinite,
          child: testAsync.when(
            data: (result) {
              final viewCount = result['view_count'] ?? 0;
              final tableCount = result['table_count'] ?? 0;
              final viewWorking = result['view_working'] ?? false;
              final dataConsistent = result['data_consistent'] ?? false;
              final error = result['error'];

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (error != null) ...[
                      Text('❌ Error: $error',
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                    ],
                    Text('View Count: $viewCount'),
                    Text('Table Count: $tableCount'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          viewWorking ? Icons.check_circle : Icons.error,
                          color: viewWorking ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          viewWorking ? 'View Working' : 'View Not Working',
                          style: TextStyle(
                            color: viewWorking ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          dataConsistent ? Icons.check_circle : Icons.warning,
                          color: dataConsistent ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dataConsistent
                              ? 'Data Consistent'
                              : 'Data Inconsistent',
                          style: TextStyle(
                            color:
                                dataConsistent ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (!dataConsistent) ...[
                      const SizedBox(height: 16),
                      const Text(
                        '⚠️ If counts don\'t match, run the location view fix SQL script.',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                    if (viewWorking && dataConsistent) ...[
                      const SizedBox(height: 16),
                      const Text(
                        '✅ Location view is working correctly!',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Text('Error: $error'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (testAsync.hasValue)
            TextButton(
              onPressed: () {
                ref.invalidate(locationViewTestProvider);
              },
              child: const Text('Retry Test'),
            ),
        ],
      ),
    );
  }
}
