import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class BackupCryptoService {
  static const encryptedBackupFormat = 'card_box_encrypted_backup';
  static const encryptedBackupVersion = 1;
  static const _pbkdf2Iterations = 120000;
  static const _saltLength = 16;
  static const _nonceLength = 12;

  final Cipher _cipher = AesGcm.with256bits();
  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  );
  final Random _random = Random.secure();

  Future<String> encryptJson({
    required String rawJson,
    required String password,
  }) async {
    final normalizedPassword = _normalizePassword(password);
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final secretKey = await _deriveKey(
      password: normalizedPassword,
      salt: salt,
    );
    final secretBox = await _cipher.encrypt(
      utf8.encode(rawJson),
      secretKey: secretKey,
      nonce: nonce,
    );
    final payload = {
      'format': encryptedBackupFormat,
      'version': encryptedBackupVersion,
      'algorithm': 'aes-256-gcm',
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _pbkdf2Iterations,
      'saltBase64': base64Encode(salt),
      'nonceBase64': base64Encode(secretBox.nonce),
      'cipherTextBase64': base64Encode(secretBox.cipherText),
      'macBase64': base64Encode(secretBox.mac.bytes),
      'exportedAt': DateTime.now().toIso8601String(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<String> decryptJson({
    required String encryptedJson,
    required String password,
  }) async {
    final decoded = jsonDecode(encryptedJson);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Encrypted backup must be a JSON object.');
    }
    final format = decoded['format'] as String? ?? '';
    if (format != encryptedBackupFormat) {
      throw const FormatException(
        'This file is not an encrypted Card Box backup.',
      );
    }
    final version = decoded['version'] as int? ?? 1;
    if (version > encryptedBackupVersion) {
      throw FormatException(
        'Encrypted backup version $version is newer than this app supports.',
      );
    }
    final iterations = decoded['iterations'] as int? ?? _pbkdf2Iterations;
    final salt = _decodeRequiredBase64(decoded['saltBase64'], 'salt');
    final nonce = _decodeRequiredBase64(decoded['nonceBase64'], 'nonce');
    final cipherText = _decodeRequiredBase64(
      decoded['cipherTextBase64'],
      'cipherText',
    );
    final macBytes = _decodeRequiredBase64(decoded['macBase64'], 'mac');

    final secretKey = await _deriveKey(
      password: _normalizePassword(password),
      salt: salt,
      iterations: iterations,
    );
    try {
      final clearBytes = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: secretKey,
      );
      return utf8.decode(clearBytes);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'Backup password did not match this encrypted file.',
      );
    }
  }

  bool looksEncrypted(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      return decoded is Map<String, Object?> &&
          decoded['format'] == encryptedBackupFormat;
    } catch (_) {
      return false;
    }
  }

  Future<SecretKey> _deriveKey({
    required String password,
    required List<int> salt,
    int iterations = _pbkdf2Iterations,
  }) {
    final pbkdf2 = iterations == _pbkdf2Iterations
        ? _pbkdf2
        : Pbkdf2(
            macAlgorithm: Hmac.sha256(),
            iterations: iterations,
            bits: 256,
          );
    return pbkdf2.deriveKeyFromPassword(password: password, nonce: salt);
  }

  Uint8List _decodeRequiredBase64(Object? value, String field) {
    if (value is! String || value.isEmpty) {
      throw FormatException('Encrypted backup is missing $field.');
    }
    try {
      return Uint8List.fromList(base64Decode(value));
    } catch (_) {
      throw FormatException('Encrypted backup has invalid $field data.');
    }
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var index = 0; index < length; index++) {
      bytes[index] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Trim, then enforce the 8-character minimum on the *trimmed*
  /// length. The user-visible copy says "at least 8 characters",
  /// and PBKDF2 derives the key from the trimmed value — so the
  /// check must use the same input that goes into the KDF.
  ///
  /// A password of seven non-whitespace characters padded to
  /// fifteen with spaces would have passed the previous check
  /// (which used the trimmed length) but produced a key with only
  /// seven characters of entropy. Reject it.
  String _normalizePassword(String password) {
    final trimmed = password.trim();
    if (trimmed.length < 8) {
      throw const FormatException(
        'Use a backup password with at least 8 non-whitespace '
        'characters.',
      );
    }
    return trimmed;
  }
}
