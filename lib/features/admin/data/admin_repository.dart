import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rentlens/core/models/admin.dart';
import 'package:rentlens/core/models/report.dart';
import 'package:rentlens/features/auth/domain/models/user_profile.dart';

class AdminRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // =============================================
  // ADMIN AUTHENTICATION
  // =============================================

  /// Check if email and password match an admin account
  Future<Admin?> authenticateAdmin(String email, String password) async {
    try {
      // In production, you should hash the password and compare hashes
      // For now, we'll do a simple password check
      final response = await _supabase
          .from('admins')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      // TODO: Implement proper password hashing verification
      // For now, storing plain password in database (NOT RECOMMENDED FOR PRODUCTION)
      // You should use bcrypt or similar to hash passwords
      final storedPasswordHash = response['password_hash'] as String;

      // Simple comparison (REPLACE WITH BCRYPT VERIFICATION IN PRODUCTION)
      if (storedPasswordHash == password) {
        return Admin.fromJson(response);
      }

      return null;
    } catch (e) {
      print('Error authenticating admin: $e');
      return null;
    }
  }

  /// Get admin by email
  Future<Admin?> getAdminByEmail(String email) async {
    try {
      final response = await _supabase
          .from('admins')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response == null) return null;
      return Admin.fromJson(response);
    } catch (e) {
      print('Error getting admin: $e');
      return null;
    }
  }

  // =============================================
  // USER MANAGEMENT
  // =============================================

  /// Get all users with optional filters
  Future<List<UserProfile>> getAllUsers({
    bool? isBanned,
    int? limit,
    int? offset,
  }) async {
    try {
      dynamic query = _supabase.from('users').select();

      if (isBanned != null) {
        query = query.eq('is_banned', isBanned);
      }

      query = query.order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 10) - 1);
      }

      final response = await query;
      return (response as List).map((e) => UserProfile.fromJson(e)).toList();
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  /// Ban a user
  Future<bool> banUser({
    required String userId,
    required String adminId,
    required String reason,
  }) async {
    try {
      print('═══════════════════════════════════════════');
      print('🔨 BAN USER OPERATION STARTED');
      print('═══════════════════════════════════════════');
      print('📋 Parameters:');
      print('   User ID: $userId');
      print('   Admin ID: $adminId');
      print('   Reason: $reason');
      print('   Reason length: ${reason.length}');
      print('───────────────────────────────────────────');

      // Validate inputs
      if (userId.isEmpty) {
        print('❌ VALIDATION ERROR: User ID is empty');
        return false;
      }
      if (adminId.isEmpty) {
        print('❌ VALIDATION ERROR: Admin ID is empty');
        return false;
      }
      if (reason.isEmpty) {
        print('❌ VALIDATION ERROR: Reason is empty');
        return false;
      }

      print('✅ Validation passed');
      print('📡 Calling RPC function: admin_ban_user');

      // Call SQL function
      final response = await _supabase.rpc(
        'admin_ban_user',
        params: {
          'p_user_id': userId,
          'p_admin_id': adminId,
          'p_reason': reason,
        },
      );

      print('───────────────────────────────────────────');
      print('📥 RPC Response received:');
      print('   Type: ${response.runtimeType}');
      print('   Data: $response');
      print('───────────────────────────────────────────');

      // Handle response
      if (response == null) {
        print('❌ ERROR: Response is null');
        print('   Possible causes:');
        print('   - Function admin_ban_user does not exist');
        print('   - Function has wrong signature');
        print('   - Database connection issue');
        return false;
      }

      if (response is Map) {
        final success = response['success'];
        final error = response['error'];
        final message = response['message'];

        print('📊 Response Analysis:');
        print('   Success: $success');
        print('   Error: $error');
        print('   Message: $message');

        if (success == true) {
          print('✅ BAN SUCCESSFUL!');
          print('═══════════════════════════════════════════');
          return true;
        } else {
          print('❌ BAN FAILED!');
          print('   Error message: $error');
          print('═══════════════════════════════════════════');
          return false;
        }
      } else {
        print('❌ UNEXPECTED RESPONSE TYPE: ${response.runtimeType}');
        print('   Expected: Map');
        print('   Got: $response');
        print('═══════════════════════════════════════════');
        return false;
      }
    } on PostgrestException catch (e) {
      print('═══════════════════════════════════════════');
      print('❌ POSTGREST EXCEPTION');
      print('═══════════════════════════════════════════');
      print('📛 Error Details:');
      print('   Message: ${e.message}');
      print('   Code: ${e.code}');
      print('   Details: ${e.details}');
      print('   Hint: ${e.hint}');
      print('───────────────────────────────────────────');
      print('💡 Possible Solutions:');
      if (e.code == 'PGRST202' || e.message.contains('Could not find')) {
        print('   → Function admin_ban_user not found');
        print('   → Run supabase_ADMIN_VIEWS_FUNCTIONS_FIX.sql');
      } else if (e.code == '42883') {
        print('   → Function signature mismatch');
        print('   → Check parameter types (UUID, UUID, TEXT)');
      } else {
        print('   → Check database logs');
        print('   → Verify permissions');
      }
      print('═══════════════════════════════════════════');
      return false;
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════');
      print('❌ UNEXPECTED EXCEPTION');
      print('═══════════════════════════════════════════');
      print('   Error type: ${e.runtimeType}');
      print('   Message: $e');
      print('   Stack trace: $stackTrace');
      print('═══════════════════════════════════════════');
      return false;
    }
  }

  /// Unban a user
  Future<bool> unbanUser(String userId) async {
    try {
      print('🔓 Attempting to unban user...');
      print('   User ID: $userId');

      // Call SQL function
      final response = await _supabase.rpc(
        'admin_unban_user',
        params: {
          'p_user_id': userId,
        },
      );

      print('📥 Response from unban function: $response');

      if (response != null && response['success'] == true) {
        print('✅ User unbanned successfully!');
        return true;
      } else {
        final errorMsg = response?['error'] ?? 'Unknown error';
        print('❌ Failed to unban user: $errorMsg');
        return false;
      }
    } catch (e) {
      print('❌ Exception while unbanning user: $e');
      print('   Error type: ${e.runtimeType}');
      return false;
    }
  }

  /// Get banned users with details
  Future<List<Map<String, dynamic>>> getBannedUsers() async {
    try {
      final response = await _supabase.from('admin_banned_users_view').select();

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error getting banned users: $e');
      return [];
    }
  }

  // =============================================
  // REPORTS MANAGEMENT
  // =============================================

  /// Get all reports with optional status filter
  Future<List<ReportWithDetails>> getReports({
    ReportStatus? status,
    ReportType? type,
    int? limit,
  }) async {
    try {
      dynamic query = _supabase.from('admin_reports_view').select();

      if (status != null) {
        query = query.eq('status', status.value);
      }

      if (type != null) {
        query = query.eq('report_type', type.value);
      }

      query = query.order('created_at', ascending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      return (response as List)
          .map((e) => ReportWithDetails.fromJson(e))
          .toList();
    } catch (e) {
      print('Error getting reports: $e');
      return [];
    }
  }

  /// Get report by ID
  Future<ReportWithDetails?> getReportById(String reportId) async {
    try {
      final response = await _supabase
          .from('admin_reports_view')
          .select()
          .eq('id', reportId)
          .maybeSingle();

      if (response == null) return null;
      return ReportWithDetails.fromJson(response);
    } catch (e) {
      print('Error getting report: $e');
      return null;
    }
  }

  /// Update report status
  Future<bool> updateReportStatus({
    required String reportId,
    required ReportStatus status,
    required String adminId,
    String? adminNotes,
  }) async {
    try {
      await _supabase.from('reports').update({
        'status': status.value,
        'reviewed_by': adminId,
        'reviewed_at': DateTime.now().toIso8601String(),
        'admin_notes': adminNotes,
      }).eq('id', reportId);

      return true;
    } catch (e) {
      print('Error updating report: $e');
      return false;
    }
  }

  /// Create a report (for users)
  Future<Report?> createReport({
    required String reporterId,
    required ReportType type,
    String? reportedUserId,
    String? reportedProductId,
    required String reason,
    String? description,
  }) async {
    try {
      final response = await _supabase
          .from('reports')
          .insert({
            'reporter_id': reporterId,
            'report_type': type.value,
            'reported_user_id': reportedUserId,
            'reported_product_id': reportedProductId,
            'reason': reason,
            'description': description,
            'status': ReportStatus.pending.value,
          })
          .select()
          .single();

      return Report.fromJson(response);
    } catch (e) {
      print('Error creating report: $e');
      return null;
    }
  }

  // =============================================
  // STATISTICS
  // =============================================

  /// Get admin dashboard statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      // Get counts sequentially (Supabase count syntax)
      final totalUsers =
          await _supabase.from('users').select('id').count(CountOption.exact);

      final bannedUsers = await _supabase
          .from('users')
          .select('id')
          .eq('is_banned', true)
          .count(CountOption.exact);

      final pendingReports = await _supabase
          .from('reports')
          .select('id')
          .eq('status', ReportStatus.pending.value)
          .count(CountOption.exact);

      final totalReports =
          await _supabase.from('reports').select('id').count(CountOption.exact);

      return {
        'total_users': totalUsers.count,
        'banned_users': bannedUsers.count,
        'pending_reports': pendingReports.count,
        'total_reports': totalReports.count,
      };
    } catch (e) {
      print('❌ Error getting statistics: $e');
      // Return default values instead of empty map
      return {
        'total_users': 0,
        'banned_users': 0,
        'pending_reports': 0,
        'total_reports': 0,
      };
    }
  }

  // =============================================
  // PRODUCT MANAGEMENT
  // =============================================

  /// Delete a product (admin action)
  Future<bool> deleteProduct(String productId) async {
    try {
      await _supabase.from('products').delete().eq('id', productId);
      return true;
    } catch (e) {
      print('Error deleting product: $e');
      return false;
    }
  }

  /// Get user's reports count
  Future<int> getUserReportsCount(String userId) async {
    try {
      final response = await _supabase
          .from('reports')
          .select('id')
          .eq('reported_user_id', userId)
          .count(CountOption.exact);

      return response.count;
    } catch (e) {
      print('Error getting user reports count: $e');
      return 0;
    }
  }
}
