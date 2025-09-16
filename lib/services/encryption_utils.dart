import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class EncryptionUtils {
  // Hash PIN using SHA256 with salt
  static String hashPin(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Generate random salt
  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }

  // Hash metadata for blockchain storage
  static String hashMetadata(Map<String, dynamic> metadata) {
    final jsonString = json.encode(metadata);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Generate secure random string for share IDs
  static String generateShareId() {
    final random = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Verify PIN against hash
  static bool verifyPin(String pin, String hash, String salt) {
    return hashPin(pin, salt) == hash;
  }

  // Generate random numeric PIN
  static String generatePin(int length) {
    final random = Random.secure();
    return List.generate(length, (index) => random.nextInt(10).toString()).join();
  }
}