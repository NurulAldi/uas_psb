import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/core/models/report.dart';
import 'package:rentlens/features/admin/data/admin_repository.dart';
import 'package:rentlens/features/admin/providers/admin_provider.dart';
import 'package:rentlens/features/auth/controllers/auth_controller.dart';
import 'package:rentlens/core/constants/app_strings.dart';

final reportsProvider = FutureProvider.autoDispose
    .family<List<ReportWithDetails>, ReportStatus?>((ref, status) async {
  final adminRepo = ref.watch(adminRepositoryProvider);
  return await adminRepo.getReports(status: status);
});

class ReportsManagementScreen extends ConsumerStatefulWidget {
  const ReportsManagementScreen({super.key});

  @override
  ConsumerState<ReportsManagementScreen> createState() =>
      _ReportsManagementScreenState();
}

class _ReportsManagementScreenState
    extends ConsumerState<ReportsManagementScreen> {
  ReportStatus? _selectedStatus;

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
            Text('${AppStrings.reportId}: ${report.id}'),
            const SizedBox(height: 8),
            Text('${AppStrings.type}: ${report.reportType.value}'),
            const SizedBox(height: 8),
            Text('${AppStrings.reporter}: ${report.reporterName}'),
            const SizedBox(height: 16),
            Text('${AppStrings.reportReason}: ${report.reason}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (report.description != null) ...[
              const SizedBox(height: 8),
              Text('${AppStrings.descriptionLabel}: ${report.description}'),
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
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ReportStatus.rejected),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(AppStrings.reject),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ReportStatus.resolved),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text(AppStrings.resolveReport),
          ),
        ],
      ),
    );

    if (selectedStatus != null && mounted) {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null || currentUser.role != 'admin') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${AppStrings.error}: ${AppStrings.adminAccessRequired}'),
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
            SnackBar(
                content: Text('Laporan ${selectedStatus.label.toLowerCase()}')),
          );
          ref.invalidate(reportsProvider(_selectedStatus));
          ref.invalidate(reportsProvider(null));
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status filter (compact dropdown)
            Row(
              children: [
                const Text(
                  'Filter:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                DropdownButton<ReportStatus?>(
                  value: _selectedStatus,
                  hint: const Text(AppStrings.allReportsTab),
                  items: [
                    const DropdownMenuItem<ReportStatus?>(
                      value: null,
                      child: Text(AppStrings.allReportsTab),
                    ),
                    for (final status in ReportStatus.values)
                      if (status != ReportStatus.reviewed)
                        DropdownMenuItem<ReportStatus?>(
                          value: status,
                          child: Text(status.label),
                        ),
                  ],
                  onChanged: (value) => setState(() => _selectedStatus = value),
                  underline: Container(height: 1, color: Colors.grey[300]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Report list
            Expanded(child: _buildReportsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList() {
    final reportsAsync = ref.watch(reportsProvider(_selectedStatus));

    return reportsAsync.when(
      data: (reports) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(reportsProvider(_selectedStatus));
        },
        child: reports.isEmpty
            ? const Center(child: Text(AppStrings.noReportsFound))
            : ListView.builder(
                padding: const EdgeInsets.all(8),
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
            Text('${AppStrings.error}: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(reportsProvider(_selectedStatus)),
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
                  _buildInfoRow(
                      AppStrings.descriptionLabel, report.description!),
                const Divider(),
                if (report.reportType == ReportType.user) ...[
                  _buildInfoRow('Pengguna yang Dilaporkan',
                      report.reportedUserName ?? 'N/A'),
                  _buildInfoRow(
                      'Email Pengguna', report.reportedUserEmail ?? 'N/A'),
                  _buildInfoRow('Diblokir',
                      report.reportedUserIsBanned == true ? 'Ya' : 'Tidak',
                      valueColor: report.reportedUserIsBanned == true
                          ? AppColors.error
                          : null),
                ] else ...[
                  _buildInfoRow('Produk yang Dilaporkan',
                      report.reportedProductName ?? 'N/A'),
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
