enum ReportType {
  user('user'),
  product('product');

  final String value;
  const ReportType(this.value);

  static ReportType fromString(String value) {
    return ReportType.values.firstWhere((e) => e.value == value);
  }
}

enum ReportStatus {
  pending('pending'),
  reviewed('reviewed'),
  resolved('resolved'),
  rejected('rejected');

  final String value;
  const ReportStatus(this.value);

  static ReportStatus fromString(String value) {
    return ReportStatus.values.firstWhere((e) => e.value == value);
  }

  String get label {
    switch (this) {
      case ReportStatus.pending:
        return 'Menunggu';
      case ReportStatus.reviewed:
        return 'Ditinjau';
      case ReportStatus.resolved:
        return 'Selesai';
      case ReportStatus.rejected:
        return 'Ditolak';
    }
  }
}

class Report {
  final String id;
  final String reporterId;
  final ReportType reportType;
  final String? reportedUserId;
  final String? reportedProductId;
  final String reason;
  final String? description;
  final ReportStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Report({
    required this.id,
    required this.reporterId,
    required this.reportType,
    this.reportedUserId,
    this.reportedProductId,
    required this.reason,
    this.description,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      reportType: ReportType.fromString(json['report_type'] as String),
      reportedUserId: json['reported_user_id'] as String?,
      reportedProductId: json['reported_product_id'] as String?,
      reason: json['reason'] as String,
      description: json['description'] as String?,
      status: ReportStatus.fromString(json['status'] as String),
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      adminNotes: json['admin_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'report_type': reportType.value,
      'reported_user_id': reportedUserId,
      'reported_product_id': reportedProductId,
      'reason': reason,
      'description': description,
      'status': status.value,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Extended report model with related data (from view)
class ReportWithDetails {
  final String id;
  final ReportType reportType;
  final String reason;
  final String? description;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reviewedAt;
  final String? adminNotes;

  // Reporter info
  final String reporterId;
  final String reporterName;
  final String reporterEmail;

  // Reported user info (if applicable)
  final String? reportedUserId;
  final String? reportedUserName;
  final String? reportedUserEmail;
  final bool? reportedUserIsBanned;

  // Reported product info (if applicable)
  final String? reportedProductId;
  final String? reportedProductName;
  final String? reportedProductOwnerId;

  // Admin reviewer info
  final String? reviewedById;
  final String? reviewedByName;

  ReportWithDetails({
    required this.id,
    required this.reportType,
    required this.reason,
    this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reviewedAt,
    this.adminNotes,
    required this.reporterId,
    required this.reporterName,
    required this.reporterEmail,
    this.reportedUserId,
    this.reportedUserName,
    this.reportedUserEmail,
    this.reportedUserIsBanned,
    this.reportedProductId,
    this.reportedProductName,
    this.reportedProductOwnerId,
    this.reviewedById,
    this.reviewedByName,
  });

  factory ReportWithDetails.fromJson(Map<String, dynamic> json) {
    return ReportWithDetails(
      id: json['id'] as String,
      reportType: ReportType.fromString(json['report_type'] as String),
      reason: json['reason'] as String,
      description: json['description'] as String?,
      status: ReportStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      adminNotes: json['admin_notes'] as String?,
      reporterId: json['reporter_id'] as String,
      reporterName: json['reporter_name'] as String,
      reporterEmail: json['reporter_email'] as String,
      reportedUserId: json['reported_user_id'] as String?,
      reportedUserName: json['reported_user_name'] as String?,
      reportedUserEmail: json['reported_user_email'] as String?,
      reportedUserIsBanned: json['reported_user_is_banned'] as bool?,
      reportedProductId: json['reported_product_id'] as String?,
      reportedProductName: json['reported_product_name'] as String?,
      reportedProductOwnerId: json['reported_product_owner_id'] as String?,
      reviewedById: json['reviewed_by_id'] as String?,
      reviewedByName: json['reviewed_by_name'] as String?,
    );
  }
}
