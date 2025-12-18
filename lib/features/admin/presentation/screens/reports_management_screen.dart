import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/core/models/report.dart';
import 'package:rentlens/features/admin/data/admin_repository.dart';
import 'package:rentlens/features/admin/providers/admin_provider.dart';
import 'package:rentlens/features/auth/controllers/auth_controller.dart';
import 'package:rentlens/core/strings/app_strings.dart';

final reportsProvider =
    FutureProvider.autoDispose<List<ReportWithDetails>>((ref) async {
  final adminRepo = ref.watch(adminRepositoryProvider);
  return await adminRepo.getReports();
});

final pendingReportsProvider =
    FutureProvider.autoDispose<List<ReportWithDetails>>((ref) async {
  final adminRepo = ref.watch(adminRepositoryProvider);
  return await adminRepo.getReports(status: ReportStatus.pending);
});

class ReportsManagementScreen extends ConsumerStatefulWidget {
  const ReportsManagementScreen({super.key});

  @override
  ConsumerState<ReportsManagementScreen> createState() =>
      _ReportsManagementScreenState();
}

class _ReportsManagementScreenState
    extends ConsumerState<ReportsManagementScreen>
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

  Future<void> _handleReport(ReportWithDetails report) async {
     final notesController = TextEditingController();
     final selectedStatus = await showDialog<ReportStatus>(
       context: context,
       builder: (context) => AlertDialog(
        title: const Text(AppStrings.reviewReport),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
-            Text('Report ID: ${report.id}'),
+            Text('${AppStrings.reportId}: ${report.id}'),
             const SizedBox(height: 8),
-            Text('Type: ${report.reportType.value}'),
+            Text('${AppStrings.type}: ${report.reportType.value}'),
             const SizedBox(height: 8),
-            Text('Reporter: ${report.reporterName}'),
+            Text('${AppStrings.reporter}: ${report.reporterName}'),
             const SizedBox(height: 16),
-            Text('Reason: ${report.reason}',
-                style: const TextStyle(fontWeight: FontWeight.bold)),
+            Text('${AppStrings.reportReason}: ${report.reason}',
+                style: const TextStyle(fontWeight: FontWeight.bold)),
             if (report.description != null) ...[
               const SizedBox(height: 8),
-              Text('Description: ${report.description}'),
+              Text('${AppStrings.descriptionLabel}: ${report.description}'),
             ],
             const SizedBox(height: 16),
             TextField(
               controller: notesController,
               decoration: const InputDecoration(
                 labelText: 'Admin Notes',
                 border: OutlineInputBorder(),
               ),
               maxLines: 3,
             ),
           ],
         ),
         actions: [
           TextButton(
-            onPressed: () => Navigator.pop(context),
-            child: const Text('Cancel'),
+            onPressed: () => Navigator.pop(context),
+            child: const Text(AppStrings.cancel),
           ),
-          TextButton(
-            onPressed: () => Navigator.pop(context, ReportStatus.rejected),
-            style: TextButton.styleFrom(foregroundColor: AppColors.error),
-            child: const Text('Reject'),
-          ),
-          TextButton(
-            onPressed: () => Navigator.pop(context, ReportStatus.resolved),
-            style: TextButton.styleFrom(foregroundColor: Colors.green),
-            child: const Text('Resolve'),
-          ),
+          TextButton(
+            onPressed: () => Navigator.pop(context, ReportStatus.rejected),
+            style: TextButton.styleFrom(foregroundColor: AppColors.error),
+            child: const Text(AppStrings.reject),
+          ),
+          TextButton(
+            onPressed: () => Navigator.pop(context, ReportStatus.resolved),
+            style: TextButton.styleFrom(foregroundColor: Colors.green),
+            child: const Text(AppStrings.resolveReport),
+          ),
         ],
       ),
     );

    if (selectedStatus != null && mounted) {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null || currentUser.role != 'admin') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppStrings.error}: ${AppStrings.adminAccessRequired}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final adminRepo = ref.read(adminRepositoryProvider);
      final success = await adminRepo.updateReportStatus(
        reportId: report.id,
        status: selectedStatus,
        adminId: currentUser.id,
        adminNotes: notesController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Laporan ${selectedStatus.label.toLowerCase()}')),
          );
          ref.invalidate(reportsProvider);
          ref.invalidate(pendingReportsProvider);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.failedToUpdateReport)),
          );
        }
      }
    }

    notesController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.reportManagement),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: AppStrings.pendingTab),
            Tab(text: AppStrings.allReportsTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildAllReportsTab(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    final reportsAsync = ref.watch(pendingReportsProvider);

    return reportsAsync.when(
      data: (reports) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pendingReportsProvider);
        },
        child: reports.isEmpty
            ? const Center(child: Text(AppStrings.noPendingReports))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return _buildReportCard(report);
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
-            Text('Error: $error'),
+            Text('${AppStrings.error}: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(pendingReportsProvider),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllReportsTab() {
    final reportsAsync = ref.watch(reportsProvider);

    return reportsAsync.when(
      data: (reports) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(reportsProvider);
        },
        child: reports.isEmpty
            ? const Center(child: Text(AppStrings.noReportsFound))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return _buildReportCard(report);
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
-            Text('Error: $error'),
+            Text('${AppStrings.error}: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(reportsProvider),
              child: const Text(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(ReportWithDetails report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(report.status).withOpacity(0.1),
          child: Icon(
            report.reportType == ReportType.user
                ? Icons.person_off
                : Icons.camera_alt_outlined,
            color: _getStatusColor(report.status),
          ),
        ),
        title: Text(
          '${report.reportType.value.toUpperCase()} Report',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By: ${report.reporterName}'),
            Text(
              'Status: ${report.status.label}',
              style: TextStyle(
                color: _getStatusColor(report.status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(AppStrings.reportId, report.id.substring(0, 8)),
                _buildInfoRow(AppStrings.reporter, report.reporterName),
                _buildInfoRow('Email Pelapor', report.reporterEmail),
                const Divider(),
                _buildInfoRow(AppStrings.reportReason, report.reason),
                if (report.description != null)
                  _buildInfoRow(AppStrings.descriptionLabel, report.description!),
                const Divider(),
                if (report.reportType == ReportType.user) ...[
                  _buildInfoRow(
                      'Pengguna yang Dilaporkan', report.reportedUserName ?? 'N/A'),
                  _buildInfoRow(
                      'Email Pengguna', report.reportedUserEmail ?? 'N/A'),
                  _buildInfoRow('Diblokir',
                      report.reportedUserIsBanned == true ? 'Ya' : 'Tidak',
                      valueColor: report.reportedUserIsBanned == true
                          ? AppColors.error
                          : null),
                ] else ...[
                  _buildInfoRow(
                      'Produk yang Dilaporkan', report.reportedProductName ?? 'N/A'),
                ],
                const Divider(),
                _buildInfoRow('Dibuat Pada',
                    DateFormat('dd MMM yyyy HH:mm').format(report.createdAt)),
                if (report.reviewedAt != null)
                  _buildInfoRow(
                      AppStrings.reviewedAt,
                      DateFormat('dd MMM yyyy HH:mm')
                          .format(report.reviewedAt!)),
                if (report.reviewedByName != null)
                  _buildInfoRow(AppStrings.reviewedBy, report.reviewedByName!),
                if (report.adminNotes != null)
                  _buildInfoRow(AppStrings.adminNotes, report.adminNotes!),
                if (report.status == ReportStatus.pending) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _handleReport(report),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Review Report'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
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
            child: Text(
              value,
              style: TextStyle(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.reviewed:
        return Colors.blue;
      case ReportStatus.resolved:
        return Colors.green;
      case ReportStatus.rejected:
        return AppColors.error;
    }
  }
}
