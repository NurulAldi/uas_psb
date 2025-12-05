import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class ImageUploadService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _bucketName = 'product-images';

  /// Upload a product image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String> uploadProductImage({
    required File imageFile,
    required String userId,
  }) async {
    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${path.basename(imageFile.path)}';
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
      throw Exception('Failed to upload image: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error during image upload: $e');
    }
  }

  /// Delete a product image from Supabase Storage
  /// Extracts the file path from the public URL and deletes it
  Future<void> deleteProductImage(String imageUrl) async {
    try {
      // Extract file path from public URL
      // Example URL: https://xxx.supabase.co/storage/v1/object/public/product-images/userId/timestamp_file.jpg
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Find the index of 'product-images' and get everything after it
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex == -1 || bucketIndex == pathSegments.length - 1) {
        throw Exception('Invalid image URL format');
      }

      // Reconstruct the file path (everything after bucket name)
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

      // Delete file from Storage
      await _supabase.storage.from(_bucketName).remove([filePath]);
    } on StorageException catch (e) {
      // Log but don't throw - image deletion is not critical
      print('Warning: Failed to delete image from storage: ${e.message}');
    } catch (e) {
      print('Warning: Unexpected error during image deletion: $e');
    }
  }

  /// Replace an existing product image
  /// Deletes the old image and uploads the new one
  Future<String> replaceProductImage({
    required File newImageFile,
    required String userId,
    required String oldImageUrl,
  }) async {
    // Upload new image first
    final newImageUrl = await uploadProductImage(
      imageFile: newImageFile,
      userId: userId,
    );

    // Delete old image (non-blocking)
    deleteProductImage(oldImageUrl).catchError((e) {
      print('Warning: Failed to delete old image: $e');
    });

    return newImageUrl;
  }
}
