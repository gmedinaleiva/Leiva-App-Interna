import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/security/idempotency_key.dart';

class PushInstallationStore {
  PushInstallationStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _installationKey = 'leiva_push_installation_id';
  static const _credentialKey = 'leiva_push_device_credential';
  static const _credentialSchemeKey = 'leiva_push_device_credential_scheme';
  static const _credentialExpiresKey = 'leiva_push_device_credential_expires';

  final FlutterSecureStorage _storage;

  Future<String> readOrCreate() async {
    final current = await _storage.read(key: _installationKey);
    if (current != null && current.length >= 16) return current;
    final created = newIdempotencyKey();
    await _storage.write(key: _installationKey, value: created);
    return created;
  }

  Future<StoredDeviceEnrollment?> readEnrollment() async {
    final credential = await _storage.read(key: _credentialKey);
    final expiresValue = await _storage.read(key: _credentialExpiresKey);
    final expiresAt = DateTime.tryParse(expiresValue ?? '');
    if (credential == null || credential.length < 32 || expiresAt == null) {
      if (credential != null || expiresValue != null) await clearEnrollment();
      return null;
    }
    if (!expiresAt.isAfter(DateTime.now().toUtc())) {
      await clearEnrollment();
      return null;
    }
    final scheme = await _storage.read(key: _credentialSchemeKey);
    return StoredDeviceEnrollment(
      credential: credential,
      scheme: scheme ?? 'Device',
      expiresAt: expiresAt,
    );
  }

  Future<void> writeEnrollment(StoredDeviceEnrollment enrollment) async {
    await _storage.write(key: _credentialKey, value: enrollment.credential);
    await _storage.write(key: _credentialSchemeKey, value: enrollment.scheme);
    await _storage.write(
      key: _credentialExpiresKey,
      value: enrollment.expiresAt.toUtc().toIso8601String(),
    );
  }

  Future<void> clearEnrollment() async {
    await _storage.delete(key: _credentialKey);
    await _storage.delete(key: _credentialSchemeKey);
    await _storage.delete(key: _credentialExpiresKey);
  }
}

class StoredDeviceEnrollment {
  const StoredDeviceEnrollment({
    required this.credential,
    required this.scheme,
    required this.expiresAt,
  });

  final String credential;
  final String scheme;
  final DateTime expiresAt;
}
