import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentlens/features/admin/data/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});
