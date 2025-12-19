import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/core/constants/app_strings.dart';
import 'package:rentlens/features/admin/providers/report_provider.dart';

/// Report User Dialog
/// Shows a form to report a user with a reason
class ReportUserDialog extends ConsumerStatefulWidget {
  final String reportedUserId;
  final String reportedUserName;

  const ReportUserDialog({
    super.key,
    required this.reportedUserId,
    required this.reportedUserName,
  });

  @override
  ConsumerState<ReportUserDialog> createState() => _ReportUserDialogState();
}

class _ReportUserDialogState extends ConsumerState<ReportUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final controller = ref.read(reportManagementControllerProvider.notifier);
    final success = await controller.createReport(
      reportedUserId: widget.reportedUserId,
      reason: _reasonController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.reportSubmittedSuccessfully),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.failedToSubmitReport),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Make dialog content scrollable and constrained to avoid overflow on
      // small screens or when the keyboard is visible.
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Row(
        children: [
          Icon(Icons.flag, color: Colors.red[700]),
          const SizedBox(width: 8),
          const Text(AppStrings.reportUser),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          // Keep dialog to a reasonable fraction of the screen height
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are reporting: ${widget.reportedUserName}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: AppStrings.reportReason,
                    hintText: AppStrings.reportReasonHint,
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppStrings.reportReasonRequired;
                    }
                    if (value.trim().length < 10) {
                      return AppStrings.reportReasonMinLength;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Reports are reviewed by administrators. False reports may result in action against your account.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700],
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
