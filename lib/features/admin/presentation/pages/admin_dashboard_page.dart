import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/admin/providers/report_provider.dart';
import 'package:rentlens/features/admin/domain/models/report.dart';
import 'package:rentlens/l10n/app_strings.dart';

/// Format time ago helper function
String _formatTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays > 365) {
    return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() == 1 ? '' : 's'} ago';
  } else if (difference.inDays > 30) {
    return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
  } else if (difference.inDays > 0) {
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
  } else {
    return 'Just now';
  }
}

/// Admin Dashboard Page
/// Shows all pending reports with actions to ban or dismiss
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  bool _showAllReports = false;

  @override
  Widget build(BuildContext context) {
    final reportsAsync = _showAllReports
        ? ref.watch(allReportsProvider)
        : ref.watch(pendingReportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.adminDashboard),
        backgroundColor: Colors.deepPurple[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(pendingReportsProvider);
              ref.invalidate(allReportsProvider);
            },
            tooltip: AppStrings.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple[700]!, Colors.deepPurple[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      AppStrings.reportManagement,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.reportManagementSubtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Filter toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text(AppStrings.pendingTab),
                        icon: Icon(Icons.pending_actions),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text(AppStrings.allReportsTab),
                        icon: Icon(Icons.list),
                      ),
                    ],
                    selected: {_showAllReports},
                    onSelectionChanged: (Set<bool> selected) {
                      setState(() {
                        _showAllReports = selected.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),

          // Reports list
          Expanded(
            child: reportsAsync.when(
              data: (reports) {
                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showAllReports ? Icons.inbox : Icons.check_circle,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showAllReports ? AppStrings.noReportsFound : AppStrings.noPendingReports,
                           style: TextStyle(
                             fontSize: 18,
                             fontWeight: FontWeight.w500,
                             color: Colors.grey[600],
                           ),
                         ),
                        const SizedBox(height: 8),
                        Text(
                          _showAllReports
                              ? AppStrings.noReportsFound
                              : 'Semua laporan telah ditangani',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final reportWithDetails = reports[index];
                    return _ReportCard(
                      reportWithDetails: reportWithDetails,
                      onActionTaken: () {
                        ref.invalidate(pendingReportsProvider);
                        ref.invalidate(allReportsProvider);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    const Text(
                      AppStrings.failedToLoadReports,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(pendingReportsProvider);
                        ref.invalidate(allReportsProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text(AppStrings.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Report Card Widget
class _ReportCard extends ConsumerWidget {
  final ReportWithDetails reportWithDetails;
  final VoidCallback onActionTaken;

  const _ReportCard({
    required this.reportWithDetails,
    required this.onActionTaken,
  });

  Future<void> _showBanConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text(AppStrings.banUserConfirmationTitle),
          ],
        ),
        content: Text(
          'Apakah Anda yakin memblokir ${reportWithDetails.reportedUserName}?\n\n'
          'Ini akan:\n'
          '• Mengeluarkan pengguna secara langsung\n'
          '• Mencegah login di masa depan\n'
          '• Menandai laporan ini sebagai selesai',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text(AppStrings.banUser),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final controller = ref.read(reportManagementControllerProvider.notifier);
    final success = await controller.banUserAndResolveReport(
      reportId: reportWithDetails.report.id,
      reportedUserId: reportWithDetails.report.reportedUserId,
      adminNotes: 'User banned via admin dashboard',
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${reportWithDetails.reportedUserName} ${AppStrings.userBannedSuccessfully}'),
          backgroundColor: Colors.green,
        ),
      );
      onActionTaken();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.failedToBanUser),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDismissConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text(AppStrings.dismissed),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin mengabaikan laporan ini?\n\n'
          'Laporan akan ditandai sebagai diabaikan dan tidak akan ada tindakan terhadap ${reportWithDetails.reportedUserName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.dismissed),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final controller = ref.read(reportManagementControllerProvider.notifier);
    final success = await controller.dismissReport(
      reportId: reportWithDetails.report.id,
      adminNotes: 'Report dismissed - no action required',
    );

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.reportDismissed),
          backgroundColor: Colors.green,
        ),
      );
      onActionTaken();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.failedToDismissReport),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = reportWithDetails.report;
    final isPending = report.isPending;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPending ? Colors.orange[50] : Colors.grey[50],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPending
                                ? Icons.pending_actions
                                : Icons.check_circle,
                            size: 18,
                            color: isPending ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            report.statusText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPending
                                  ? Colors.orange[900]
                                  : Colors.green[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimeAgo(report.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (reportWithDetails.reportedUserIsBanned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block, size: 14, color: Colors.red[700]),
                        const SizedBox(width: 4),
                        Text(
                          AppStrings.userBanned.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Report details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reporter info
                _InfoRow(
                  icon: Icons.person,
                  label: AppStrings.reporter,
                  value: reportWithDetails.reporterName,
                  subtitle: reportWithDetails.reporterEmail,
                ),
                const SizedBox(height: 12),

                // Reported user info
                _InfoRow(
                  icon: Icons.flag,
                  label: 'Pengguna yang Dilaporkan',
                  value: reportWithDetails.reportedUserName,
                  subtitle: reportWithDetails.reportedUserEmail,
                  isHighlighted: true,
                ),
                const SizedBox(height: 16),

                // Reason
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.description,
                              size: 16, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.reportReason,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report.reason,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Actions (only for pending reports)
          if (isPending && !reportWithDetails.reportedUserIsBanned)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDismissConfirmation(context, ref),
                      icon: const Icon(Icons.close),
                      label: const Text(AppStrings.dismissed),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showBanConfirmation(context, ref),
                      icon: const Icon(Icons.block),
                      label: const Text(AppStrings.banUser),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
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
  }
}

/// Info Row Widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final bool isHighlighted;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: isHighlighted ? Colors.red[700] : Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isHighlighted ? Colors.red[900] : Colors.black87,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
