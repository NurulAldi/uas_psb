import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class AvatarUploadService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _bucketName = 'avatars';

  /// Verify if the avatars bucket exists and is accessible
  /// Note: This requires service_role permissions and may not work for regular users
  /// It's better to just try upload directly and handle errors
  Future<bool> verifyBucket() async {
    try {
      print('🔍 AVATAR SERVICE: Checking bucket "$_bucketName"...');

      // Try to list files in bucket (lighter than listBuckets)
      // This will fail if bucket doesn't exist or user has no access
      await _supabase.storage.from(_bucketName).list(
            path: '',
            searchOptions: const SearchOptions(limit: 1),
          );

      print('✅ AVATAR SERVICE: Bucket is accessible');
      return true;
    } catch (e) {
      print('⚠️  AVATAR SERVICE: Bucket check failed - $e');
      print('   This is normal if bucket is empty or you have no access yet');
      print('   Will proceed with upload anyway...');
      // Return true anyway - let the upload fail if there's a real problem
      return true;
    }
  }

  /// Validate if an avatar URL is accessible
  Future<bool> validateAvatarUrl(String avatarUrl) async {
    try {
      print('🔍 AVATAR SERVICE: Validating URL...');
      print('   URL: $avatarUrl');

      // Extract file path from URL
      final uri = Uri.parse(avatarUrl);
      final pathSegments = uri.pathSegments;

      // Find bucket in path
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex == -1) {
        print('❌ AVATAR SERVICE: Invalid URL - bucket not found in path');
        return false;
      }

      // Get file path
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      print('   File path: $filePath');

      // Try to get file info (will throw if not exists/accessible)
      final fileList = await _supabase.storage.from(_bucketName).list(
            path: filePath.substring(0, filePath.lastIndexOf('/')),
          );

      final fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
      final fileExists = fileList.any((file) => file.name == fileName);

      if (fileExists) {
        print('✅ AVATAR SERVICE: File exists and is accessible');
        return true;
      } else {
        print('❌ AVATAR SERVICE: File not found in storage');
        return false;
      }
    } catch (e) {
      print('❌ AVATAR SERVICE: URL validation failed - $e');
      return false;
    }
  }

  /// Upload a user avatar to Supabase Storage
  /// Returns the public URL of the uploaded avatar
  Future<String> uploadAvatar({
    required File imageFile,
    required String userId,
  }) async {
    try {
      print('📤 AVATAR UPLOAD: Starting upload...');
      print('   User ID: $userId');
      print('   File: ${imageFile.path}');

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      final fileName = 'avatar_$timestamp$extension';
      final filePath = '$userId/$fileName';

      print('   Target path: $filePath');

      // Upload file to Storage
      await _supabase.storage.from(_bucketName).upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      print('✅ AVATAR UPLOAD: File uploaded successfully');

      // Get public URL
      final publicUrl =
          _supabase.storage.from(_bucketName).getPublicUrl(filePath);

      print('✅ AVATAR UPLOAD: Public URL generated');
      print('   URL: $publicUrl');

      return publicUrl;
    } on StorageException catch (e) {
      print('❌ AVATAR UPLOAD: StorageException - ${e.message}');
      print('   Status code: ${e.statusCode}');
      throw Exception('Failed to upload avatar: ${e.message}');
    } catch (e) {
      print('❌ AVATAR UPLOAD: Unexpected error - $e');
      throw Exception('Unexpected error during avatar upload: $e');
    }
  }

  /// Delete an avatar from Supabase Storage
  /// Extracts the file path from the public URL and deletes it
  Future<void> deleteAvatar(String avatarUrl) async {
    try {
      // Extract file path from public URL
      // Example URL: https://xxx.supabase.co/storage/v1/object/public/avatars/userId/avatar_timestamp.jpg
      final uri = Uri.parse(avatarUrl);
      final pathSegments = uri.pathSegments;

      // Find the index of 'avatars' and get everything after it
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex == -1 || bucketIndex == pathSegments.length - 1) {
        throw Exception('Invalid avatar URL format');
      }

      // Reconstruct the file path (everything after bucket name)
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      // Delete file from Storage
      await _supabase.storage.from(_bucketName).remove([filePath]);
    } on StorageException catch (e) {
      // Log but don't throw - avatar deletion is not critical
      print('Warning: Failed to delete avatar from storage: ${e.message}');
    } catch (e) {
      print('Warning: Unexpected error during avatar deletion: $e');
    }
  }

  /// Replace an existing avatar
  /// Deletes the old avatar and uploads the new one
  Future<String> replaceAvatar({
    required File newImageFile,
    required String userId,
    required String oldAvatarUrl,
  }) async {
    // Upload new avatar first
    final newAvatarUrl = await uploadAvatar(
      imageFile: newImageFile,
      userId: userId,
    );

    // Delete old avatar (non-blocking)
    deleteAvatar(oldAvatarUrl).catchError((e) {
      print('Warning: Failed to delete old avatar: $e');
    });

    return newAvatarUrl;
  }
}
