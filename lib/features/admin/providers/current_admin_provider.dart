import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/core/models/admin.dart';

/// Provider to check if current login is admin and store admin data
final currentAdminProvider = StateProvider<Admin?>((ref) => null);

/// Provider to check if current user is admin
final isAdminProvider = Provider<bool>((ref) {
  final admin = ref.watch(currentAdminProvider);
  return admin != null;
});
