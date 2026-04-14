import 'dart:convert';
import 'dart:typed_data';
import 'package:aes256gcm/aes256gcm.dart';
import 'package:xkyber_crypto/xkyber_crypto.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

class EncryptionService {
  static const int _keySize = 32;

  // Generate Kyber768 key pair for key exchange
  static Future<Map<String, String>> generateKeyPair() async {
    try {
      final keyPair = KyberKeyPair.generate();
      
      final publicKey = base64Encode(keyPair.publicKey);
      final privateKey = base64Encode(keyPair.secretKey);
      
      debugPrint('Generated Kyber768 key pair');
      debugPrint('Public Key length: ${keyPair.publicKey.length} bytes');
      debugPrint('Private Key length: ${keyPair.secretKey.length} bytes');
      
      return {
        'publicKey': publicKey,
        'privateKey': privateKey,
      };
    } catch (e) {
      debugPrint('Key generation error: $e');
      rethrow;
    }
  }

  // Encapsulate: Generate shared secret and ciphertext (initiator side)
  static Future<Map<String, String>> encapsulate(String theirPublicKey) async {
    try {
      debugPrint('Encapsulating with public key...');
      
      final publicKeyBytes = base64Decode(theirPublicKey);
      debugPrint('Decoded public key: ${publicKeyBytes.length} bytes');
      
      final result = KyberKEM.encapsulate(publicKeyBytes);
      
      final sharedSecret = base64Encode(result.sharedSecret.sublist(0, _keySize));
      final ciphertext = base64Encode(result.ciphertextKEM);
      
      debugPrint('✓ Encapsulation successful');
      debugPrint('Shared secret: ${sharedSecret.substring(0, 20)}...');
      debugPrint('Ciphertext length: ${result.ciphertextKEM.length} bytes');
      
      return {
        'sharedSecret': sharedSecret,
        'ciphertext': ciphertext,
      };
    } catch (e) {
      debugPrint('✗ Encapsulation failed: $e');
      throw Exception('Encapsulation failed: $e');
    }
  }

  // Decapsulate: Derive shared secret from ciphertext (responder side)
  static Future<String> decapsulate(String ciphertext, String myPrivateKey) async {
    try {
      debugPrint('Decapsulating ciphertext...');
      
      final ciphertextBytes = base64Decode(ciphertext);
      final privateKeyBytes = base64Decode(myPrivateKey);
      
      debugPrint('Ciphertext: ${ciphertextBytes.length} bytes');
      debugPrint('Private key: ${privateKeyBytes.length} bytes');
      
      final sharedSecret = KyberKEM.decapsulate(ciphertextBytes, privateKeyBytes);
      
      final sharedSecretBase64 = base64Encode(sharedSecret.sublist(0, _keySize));
      
      debugPrint('✓ Decapsulation successful');
      debugPrint('Shared secret: ${sharedSecretBase64.substring(0, 20)}...');
      
      return sharedSecretBase64;
    } catch (e) {
      debugPrint('✗ Decapsulation failed: $e');
      throw Exception('Decapsulation failed: $e');
    }
  }

  // Encrypt message using AES-256-GCM
  static Future<String> encryptMessage(String message, String sharedSecret) async {
    try {
      debugPrint('Encrypting: "$message"');
      debugPrint('Using secret: ${sharedSecret.substring(0, 20)}...');
      
      final encrypted = await Aes256Gcm.encrypt(message, sharedSecret);
      
      debugPrint('✓ Encryption successful');
      debugPrint('Ciphertext: ${encrypted.substring(0, 30)}...');
      
      return encrypted;
    } catch (e) {
      debugPrint('✗ Encryption failed: $e');
      throw Exception('Encryption failed: $e');
    }
  }

  // Decrypt message using AES-256-GCM
  static Future<String> decryptMessage(String encryptedMessage, String sharedSecret) async {
    try {
      debugPrint('Decrypting message...');
      debugPrint('Using secret: ${sharedSecret.substring(0, 20)}...');
      
      final decrypted = await Aes256Gcm.decrypt(encryptedMessage, sharedSecret);
      
      debugPrint('✓ Decryption successful: "$decrypted"');
      
      return decrypted;
    } catch (e) {
      debugPrint('✗ Decryption failed: $e');
      return '[Decryption failed]';
    }
  }

  // Generate unique ID for messages and contacts
  static String generateId() {
    final random = Random.secure();
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Encode(bytes).replaceAll('/', '_').replaceAll('+', '-');
  }
}