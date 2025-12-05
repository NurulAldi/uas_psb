import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class AvatarUploadService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _bucketName = 'avatars';

  /// Upload a user avatar to Supabase Storage
  /// Returns the public URL of the uploaded avatar
  Future<String> uploadAvatar({
    required File imageFile,
    required String userId,
  }) async {
    try {
      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      final fileName = 'avatar_$timestamp$extension';
      final filePath = '$userId/$fileName';

      // Upload file to Storage
      await _supabase.storage.from(_bucketName).upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Get public URL
      final publicUrl =
          _supabase.storage.from(_bucketName).getPublicUrl(filePath);

      return publicUrl;
    } on StorageException catch (e) {
      throw Exception('Failed to upload avatar: ${e.message}');
    } catch (e) {
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
