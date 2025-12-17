import 'package:rentlens/core/config/supabase_config.dart';
import 'package:rentlens/features/admin/domain/models/report.dart';

/// Report Repository
/// Handles all report operations with Supabase
class ReportRepository {
  final _supabase = SupabaseConfig.client;

  /// Create a new report
  Future<Report> createReport({
    required String reportedUserId,
    required String reason,
  }) async {
    try {
      final currentUserId = await SupabaseConfig.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      print('📝 REPORT REPOSITORY: Creating report...');
      print('   Reporter: $currentUserId');
      print('   Reported User: $reportedUserId');

      final response = await _supabase
          .from('reports')
          .insert({
            'reporter_id': currentUserId,
            'reported_user_id': reportedUserId,
            'reason': reason,
            'status': 'pending',
          })
          .select()
          .single();

      print('✅ REPORT REPOSITORY: Report created successfully');

      return Report.fromJson(response);
    } catch (e, stackTrace) {
      print('❌ REPORT REPOSITORY: Error creating report = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all pending reports (admin only)
  Future<List<ReportWithDetails>> getPendingReports() async {
    try {
      print('📝 REPORT REPOSITORY: Fetching pending reports...');

      final response = await _supabase
          .from('recent_reports_with_details')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      print('✅ REPORT REPOSITORY: Found ${response.length} pending reports');

      return (response as List)
          .map((json) => ReportWithDetails.fromJson(json))
          .toList();
    } catch (e, stackTrace) {
      print('❌ REPORT REPOSITORY: Error fetching reports = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all reports (admin only)
  Future<List<ReportWithDetails>> getAllReports() async {
    try {
      print('📝 REPORT REPOSITORY: Fetching all reports...');

      final response = await _supabase
          .from('recent_reports_with_details')
          .select()
          .order('created_at', ascending: false);

      print('✅ REPORT REPOSITORY: Found ${response.length} reports');

      return (response as List)
          .map((json) => ReportWithDetails.fromJson(json))
          .toList();
    } catch (e, stackTrace) {
      print('❌ REPORT REPOSITORY: Error fetching reports = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Ban user and resolve report (admin only)
  Future<void> banUserAndResolveReport({
    required String reportId,
    required String reportedUserId,
    String? adminNotes,
  }) async {
    try {
      final currentUserId = SupabaseConfig.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      print('🚫 REPORT REPOSITORY: Banning user and resolving report...');
      print('   Report ID: $reportId');
      print('   User to ban: $reportedUserId');

      // Ban the user
      await _supabase
          .from('users')
          .update({'is_banned': true}).eq('id', reportedUserId);

      // Resolve the report
      await _supabase.from('reports').update({
        'status': 'resolved',
        'resolved_by': currentUserId,
        'admin_notes': adminNotes,
      }).eq('id', reportId);

      print('✅ REPORT REPOSITORY: User banned and report resolved');
    } catch (e, stackTrace) {
      print('❌ REPORT REPOSITORY: Error banning user = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Dismiss report (admin only)
  Future<void> dismissReport({
    required String reportId,
    String? adminNotes,
  }) async {
    try {
      final currentUserId = SupabaseConfig.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      print('📝 REPORT REPOSITORY: Dismissing report...');
      print('   Report ID: $reportId');

      await _supabase.from('reports').update({
        'status': 'dismissed',
        'resolved_by': currentUserId,
        'admin_notes': adminNotes,
      }).eq('id', reportId);

      print('✅ REPORT REPOSITORY: Report dismissed');
    } catch (e, stackTrace) {
      print('❌ REPORT REPOSITORY: Error dismissing report = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
