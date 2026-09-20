import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/security/idempotency_key.dart';

class PushInstallationStore {
  PushInstallationStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _installationKey = 'leiva_push_installation_id';

  final FlutterSecureStorage _storage;

  Future<String> readOrCreate() async {
    final current = await _storage.read(key: _installationKey);
    if (current != null && current.length >= 16) return current;
    final created = newIdempotencyKey();
    await _storage.write(key: _installationKey, value: created);
    return created;
  }
}
