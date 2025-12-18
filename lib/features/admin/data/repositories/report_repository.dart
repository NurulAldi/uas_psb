import 'package:rentlens/core/config/supabase_config.dart';
import 'package:rentlens/core/constants/app_strings.dart';
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
        throw Exception(AppStrings.userNotAuthenticated);
      }

      // 🔒 APPLICATION-LEVEL VALIDATION
      if (currentUserId == reportedUserId) {
        throw Exception('Anda tidak dapat melaporkan akun sendiri');
      }

      print('📝 REPORT REPOSITORY: Creating report...');
      print('   Reporter: $currentUserId');
      print('   Reported User: $reportedUserId');
      print('   Reason: $reason');

      // 🔒 SECURITY FIX: Set user context for RLS policies before creating report
      await _supabase
          .rpc('set_user_context', params: {'user_id': currentUserId});

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
        throw Exception(AppStrings.userNotAuthenticated);
      }

      print('🚫 REPORT REPOSITORY: Banning user and resolving report...');
      print('   Report ID: $reportId');
      print('   User to ban: $reportedUserId');

      // Set user context for RLS policies
      try {
        await _supabase
            .rpc('set_user_context', params: {'user_id': currentUserId});
        print(
            '🔧 REPORT REPOSITORY: set_user_context called for $currentUserId');
      } catch (e) {
        print('⚠️ REPORT REPOSITORY: Failed to set user context: $e');
      }

      // Prefer calling the admin RPC to ban user and resolve report in one atomic operation
      try {
        final rpcResponse = await _supabase.rpc('admin_ban_user', params: {
          'p_user_id': reportedUserId,
          'p_admin_id': currentUserId,
          'p_reason': adminNotes ?? 'Banned via report',
        });

        print(
            '📥 REPORT REPOSITORY: admin_ban_user RPC response: $rpcResponse');

        if (rpcResponse is Map && rpcResponse['success'] == true) {
          // Now mark the report as resolved using admin_update_report_status
          final resolveResponse =
              await _supabase.rpc('admin_update_report_status', params: {
            'p_report_id': reportId,
            'p_status': 'resolved',
            'p_admin_id': currentUserId,
            'p_admin_notes': adminNotes,
          });

          print(
              '📥 REPORT REPOSITORY: admin_update_report_status RPC response: $resolveResponse');

          if (resolveResponse is Map && resolveResponse['success'] == true) {
            print('✅ REPORT REPOSITORY: User banned and report resolved');
          } else {
            print(
                '❌ REPORT REPOSITORY: Failed to mark report as resolved: $resolveResponse');
            throw Exception(AppStrings.failedToUpdateReport);
          }
        } else {
          print(
              '❌ REPORT REPOSITORY: admin_ban_user reported failure: $rpcResponse');
          throw Exception(AppStrings.failedToUpdateReport);
        }
      } catch (e) {
        print('❌ REPORT REPOSITORY: RPC admin_ban_user failed: $e');
        throw Exception(AppStrings.failedToUpdateReport);
      }
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
        throw Exception(AppStrings.userNotAuthenticated);
      }

      print('📝 REPORT REPOSITORY: Dismissing report...');
      print('   Report ID: $reportId');

      // Set user context for RLS policies
      try {
        await _supabase
            .rpc('set_user_context', params: {'user_id': currentUserId});
        print(
            '🔧 REPORT REPOSITORY: set_user_context called for $currentUserId');
      } catch (e) {
        print('⚠️ REPORT REPOSITORY: Failed to set user context: $e');
      }

      // Use admin_update_report_status RPC to dismiss report
      try {
        final rpcResponse =
            await _supabase.rpc('admin_update_report_status', params: {
          'p_report_id': reportId,
          'p_status': 'dismissed',
          'p_admin_id': currentUserId,
          'p_admin_notes': adminNotes,
        });

        print(
            '📥 REPORT REPOSITORY: admin_update_report_status RPC response: $rpcResponse');

        if (rpcResponse is Map && rpcResponse['success'] == true) {
          print('✅ REPORT REPOSITORY: Report dismissed');
        } else {
          print('❌ REPORT REPOSITORY: RPC reported failure: $rpcResponse');
          throw Exception(AppStrings.failedToDismissReport);
        }
      } catch (e) {
        print('❌ REPORT REPOSITORY: RPC admin_update_report_status failed: $e');
        throw Exception(AppStrings.failedToDismissReport);
      }
    } catch (e, stackTrace) {
      print('❌ REPORT REPOSITORY: Error dismissing report = $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
