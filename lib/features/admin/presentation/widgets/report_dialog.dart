import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/core/theme/app_colors.dart';
import 'package:rentlens/core/models/report.dart';
import 'package:rentlens/features/admin/data/admin_repository.dart';
import 'package:rentlens/features/admin/providers/admin_provider.dart';
import 'package:rentlens/features/auth/controllers/auth_controller.dart';
import 'package:rentlens/core/strings/app_strings.dart';

class ReportDialog extends ConsumerStatefulWidget {
  final ReportType reportType;
  final String? reportedUserId;
  final String? reportedProductId;
  final String? targetName; // Name of user or product being reported

  const ReportDialog({
    super.key,
    required this.reportType,
    this.reportedUserId,
    this.reportedProductId,
    this.targetName,
  });

  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  // Common report reasons
  final List<String> _userReportReasons = [
    'Spam atau Penipuan',
    'Perilaku Tidak Pantas',
    'Aktivitas Penipuan',
    'Pelecehan',
    'Akun Palsu',
    'Lainnya',
  ];

  final List<String> _productReportReasons = [
    'Informasi Menyesatkan',
    'Konten Tidak Pantas',
    'Diduga Penipuan',
    'Produk Palsu',
    'Harga Berlebihan',
    'Lainnya',
  ];

  String? _selectedReason;

  @override
  void dispose() {
    _reasonController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.loginToSubmitReport)),
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final report = await adminRepo.createReport(
        reporterId: currentUser.id,
        type: widget.reportType,
        reportedUserId: widget.reportedUserId,
        reportedProductId: widget.reportedProductId,
        reason: _selectedReason ?? _reasonController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        if (report != null) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.reportSubmitted),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.failedToSubmitReport),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.error}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = widget.reportType == ReportType.user
        ? _userReportReasons
        : _productReportReasons;

    return AlertDialog(
      // Make the dialog scrollable and constrain height to avoid overflow
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Row(
        children: [
          Icon(
            Icons.report_problem,
            color: AppColors.error,
          ),
          const SizedBox(width: 12),
          Text(
            widget.reportType == ReportType.user
                ? AppStrings.reportUser
                : AppStrings.reportProduct,
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.targetName != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.reportType == ReportType.user
                              ? Icons.person
                              : Icons.camera_alt,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.targetName!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Reason dropdown
                DropdownButtonFormField<String>(
                  value: _selectedReason,
                  decoration: const InputDecoration(
                    labelText: AppStrings.selectReason,
                    border: OutlineInputBorder(),
                  ),
                  items: reasons.map((reason) {
                    return DropdownMenuItem(
                      value: reason,
                      child: Text(reason),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppStrings.reportReasonRequired;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Custom reason if "Lainnya" selected
                if (_selectedReason == 'Lainnya') ...[
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: AppStrings.specifyReason,
                      hintText: AppStrings.reportReasonHint,
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_selectedReason == 'Lainnya' &&
                          (value == null || value.trim().isEmpty)) {
                        return AppStrings.reportReasonRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: AppStrings.descriptionOptional,
                    hintText: 'Tambahkan informasi tambahan...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  maxLength: 500,
                ),

                const SizedBox(height: 8),

                // Info text
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 20, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          AppStrings.reportReviewNotice,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text(AppStrings.cancel),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(AppStrings.submitReport),
        ),
      ],
    );
  }
}

// Helper function to show report dialog
Future<void> showReportDialog(
  BuildContext context, {
  required ReportType reportType,
  String? reportedUserId,
  String? reportedProductId,
  String? targetName,
}) async {
  await showDialog(
    context: context,
    builder: (context) => ReportDialog(
      reportType: reportType,
      reportedUserId: reportedUserId,
      reportedProductId: reportedProductId,
      targetName: targetName,
    ),
  );
}
