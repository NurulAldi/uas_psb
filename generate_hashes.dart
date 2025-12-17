import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  final passwords = {
    'admin123': sha256.convert(utf8.encode('admin123')).toString(),
    'password123': sha256.convert(utf8.encode('password123')).toString(),
    'demo123': sha256.convert(utf8.encode('demo123')).toString(),
  };

  print('\n=== SHA-256 Password Hashes ===\n');
  passwords.forEach((password, hash) {
    print('Password: $password');
    print('Hash: $hash');
    print('');
  });

  print('\n=== SQL UPDATE Statements ===\n');
  print(
      "UPDATE public.users SET password_hash = '${passwords['admin123']}' WHERE username = 'admin';");
  print(
      "UPDATE public.users SET password_hash = '${passwords['password123']}' WHERE username IN ('user1', 'user2');");
  print(
      "UPDATE public.users SET password_hash = '${passwords['demo123']}' WHERE username = 'demo';");
  print('');
}
