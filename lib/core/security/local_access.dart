import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class LocalAccessGateway {
  Future<String?> readRememberedUsername();
  Future<void> rememberUsername(String? username);
  Future<bool> isBiometricEnabled();
  Future<void> setBiometricEnabled(bool enabled);
  Future<bool> hasEnrolledBiometrics();
  Future<bool> authenticate(String reason);
}

class DisabledLocalAccess implements LocalAccessGateway {
  const DisabledLocalAccess();

  @override
  Future<bool> authenticate(String reason) async => false;

  @override
  Future<bool> hasEnrolledBiometrics() async => false;

  @override
  Future<bool> isBiometricEnabled() async => false;

  @override
  Future<String?> readRememberedUsername() async => null;

  @override
  Future<void> rememberUsername(String? username) async {}

  @override
  Future<void> setBiometricEnabled(bool enabled) async {}
}

class SecureLocalAccess implements LocalAccessGateway {
  SecureLocalAccess({
    FlutterSecureStorage? storage,
    LocalAuthentication? authentication,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _authentication = authentication ?? LocalAuthentication();

  static const _usernameKey = 'leiva_remembered_username';
  static const _biometricKey = 'leiva_biometric_unlock_enabled';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _authentication;

  @override
  Future<String?> readRememberedUsername() => _storage.read(key: _usernameKey);

  @override
  Future<void> rememberUsername(String? username) async {
    final value = username?.trim();
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _usernameKey);
    } else {
      await _storage.write(key: _usernameKey, value: value);
    }
  }

  @override
  Future<bool> isBiometricEnabled() async =>
      await _storage.read(key: _biometricKey) == 'true';

  @override
  Future<void> setBiometricEnabled(bool enabled) => enabled
      ? _storage.write(key: _biometricKey, value: 'true')
      : _storage.delete(key: _biometricKey);

  @override
  Future<bool> hasEnrolledBiometrics() async {
    try {
      return (await _authentication.getAvailableBiometrics()).isNotEmpty;
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    }
  }
}
