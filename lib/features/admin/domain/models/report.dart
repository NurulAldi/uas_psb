/// Report Model
import 'package:rentlens/core/constants/app_strings.dart';

class Report {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final String reason;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? resolvedBy;
  final String? adminNotes;

  const Report({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedBy,
    this.adminNotes,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      reportedUserId: json['reported_user_id'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      resolvedBy: json['resolved_by'] as String?,
      adminNotes: json['admin_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'reason': reason,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'resolved_by': resolvedBy,
      'admin_notes': adminNotes,
    };
  }

  /// Get status badge color
  String get statusText {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'resolved':
        return 'Selesai';
      case 'dismissed':
        return AppStrings.dismissedLabel;
      default:
        return status;
    }
  }

  /// Check if report is pending
  bool get isPending => status == 'pending';
}

/// Report with user details
class ReportWithDetails {
  final Report report;
  final String reporterName;
  final String reporterEmail;
  final String reportedUserName;
  final String reportedUserEmail;
  final bool reportedUserIsBanned;

  const ReportWithDetails({
    required this.report,
    required this.reporterName,
    required this.reporterEmail,
    required this.reportedUserName,
    required this.reportedUserEmail,
    required this.reportedUserIsBanned,
  });

  factory ReportWithDetails.fromJson(Map<String, dynamic> json) {
    return ReportWithDetails(
      report: Report.fromJson(json),
      reporterName: json['reporter_name'] as String? ?? 'Unknown',
      reporterEmail: json['reporter_email'] as String? ?? 'Unknown',
      reportedUserName: json['reported_user_name'] as String? ?? 'Unknown',
      reportedUserEmail: json['reported_user_email'] as String? ?? 'Unknown',
      reportedUserIsBanned: json['reported_user_is_banned'] as bool? ?? false,
    );
  }
}
