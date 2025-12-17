import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Password hashing utility for manual authentication
///
/// IMPORTANT: This is for DEMO/ACADEMIC purposes only.
/// For production, use bcrypt or similar strong hashing algorithms.
class PasswordHelper {
  /// Hash password using SHA-256
  ///
  /// Note: SHA-256 is NOT recommended for production password hashing.
  /// It's too fast and vulnerable to brute-force attacks.
  ///
  /// For demo purposes, this is acceptable for quick presentations.
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  /// Verify if plain password matches hashed password
  static bool verifyPassword(String plainPassword, String hashedPassword) {
    return hashPassword(plainPassword) == hashedPassword;
  }

  /// Generate a simple hash for demo accounts
  ///
  /// Usage:
  /// ```dart
  /// final hash = PasswordHelper.hashPassword('password123');
  /// print(hash); // Use this in SQL INSERT statements
  /// ```
  static String generateDemoHash(String password) {
    return hashPassword(password);
  }
}

/// Example usage for creating demo accounts:
/// 
/// ```dart
/// // Get hash for demo passwords
/// final adminHash = PasswordHelper.hashPassword('admin123');
/// final userHash = PasswordHelper.hashPassword('password123');
/// final demoHash = PasswordHelper.hashPassword('demo123');
/// 
/// // Use these hashes in your SQL:
/// // INSERT INTO users (username, password_hash, ...)
/// // VALUES ('admin', '$adminHash', ...)
/// ```
