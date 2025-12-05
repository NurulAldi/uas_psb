import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/admin/data/repositories/report_repository.dart';
import 'package:rentlens/features/admin/domain/models/report.dart';

/// Provider for ReportRepository
final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository();
});

/// Provider for pending reports (admin only)
final pendingReportsProvider =
    FutureProvider<List<ReportWithDetails>>((ref) async {
  final repository = ref.watch(reportRepositoryProvider);
  return await repository.getPendingReports();
});

/// Provider for all reports (admin only)
final allReportsProvider = FutureProvider<List<ReportWithDetails>>((ref) async {
  final repository = ref.watch(reportRepositoryProvider);
  return await repository.getAllReports();
});

/// State notifier for managing reports
class ReportManagementController extends StateNotifier<AsyncValue<void>> {
  final ReportRepository _repository;
  final Ref _ref;

  ReportManagementController(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  /// Create a new report
  Future<bool> createReport({
    required String reportedUserId,
    required String reason,
  }) async {
    state = const AsyncValue.loading();

    try {
      print('📝 REPORT CONTROLLER: Creating report...');

      await _repository.createReport(
        reportedUserId: reportedUserId,
        reason: reason,
      );

      state = const AsyncValue.data(null);
      print('✅ REPORT CONTROLLER: Report created successfully');

      return true;
    } catch (e, stackTrace) {
      print('❌ REPORT CONTROLLER: Error creating report = $e');
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }

  /// Ban user and resolve report
  Future<bool> banUserAndResolveReport({
    required String reportId,
    required String reportedUserId,
    String? adminNotes,
  }) async {
    state = const AsyncValue.loading();

    try {
      print('🚫 REPORT CONTROLLER: Banning user...');

      await _repository.banUserAndResolveReport(
        reportId: reportId,
        reportedUserId: reportedUserId,
        adminNotes: adminNotes,
      );

      state = const AsyncValue.data(null);
      print('✅ REPORT CONTROLLER: User banned successfully');

      // Refresh reports list
      _ref.invalidate(pendingReportsProvider);
      _ref.invalidate(allReportsProvider);

      return true;
    } catch (e, stackTrace) {
      print('❌ REPORT CONTROLLER: Error banning user = $e');
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }

  /// Dismiss report
  Future<bool> dismissReport({
    required String reportId,
    String? adminNotes,
  }) async {
    state = const AsyncValue.loading();

    try {
      print('📝 REPORT CONTROLLER: Dismissing report...');

      await _repository.dismissReport(
        reportId: reportId,
        adminNotes: adminNotes,
      );

      state = const AsyncValue.data(null);
      print('✅ REPORT CONTROLLER: Report dismissed successfully');

      // Refresh reports list
      _ref.invalidate(pendingReportsProvider);
      _ref.invalidate(allReportsProvider);

      return true;
    } catch (e, stackTrace) {
      print('❌ REPORT CONTROLLER: Error dismissing report = $e');
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }
}

/// Provider for report management controller
final reportManagementControllerProvider =
    StateNotifierProvider<ReportManagementController, AsyncValue<void>>((ref) {
  final repository = ref.watch(reportRepositoryProvider);
  return ReportManagementController(repository, ref);
});
