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
      await _supabase.from('users').update({
        'is_banned': true,
        'banned_at': DateTime.now().toIso8601String(),
        'banned_by': adminId,
        'ban_reason': reason,
      }).eq('id', userId);

      return true;
    } catch (e) {
      print('Error banning user: $e');
      return false;
    }
  }

  /// Unban a user
  Future<bool> unbanUser(String userId) async {
    try {
      await _supabase.from('users').update({
        'is_banned': false,
        'banned_at': null,
        'banned_by': null,
        'ban_reason': null,
      }).eq('id', userId);

      return true;
    } catch (e) {
      print('Error unbanning user: $e');
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

      final totalProducts = await _supabase
          .from('products')
          .select('id')
          .count(CountOption.exact);

      final totalBookings = await _supabase
          .from('bookings')
          .select('id')
          .count(CountOption.exact);

      return {
        'total_users': totalUsers.count,
        'banned_users': bannedUsers.count,
        'pending_reports': pendingReports.count,
        'total_reports': totalReports.count,
        'total_products': totalProducts.count,
        'total_bookings': totalBookings.count,
      };
    } catch (e) {
      print('Error getting statistics: $e');
      return {};
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
