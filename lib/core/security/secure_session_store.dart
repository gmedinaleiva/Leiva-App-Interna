import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStore {
  Future<String?> readSessionCookie();
  Future<void> writeSessionCookie(String value);
  Future<String?> readCsrfToken();
  Future<void> writeCsrfToken(String value);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _cookieKey = 'leiva_api_session_cookie';
  static const _csrfKey = 'leiva_api_csrf_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readSessionCookie() => _storage.read(key: _cookieKey);

  @override
  Future<void> writeSessionCookie(String value) =>
      _storage.write(key: _cookieKey, value: value);

  @override
  Future<String?> readCsrfToken() => _storage.read(key: _csrfKey);

  @override
  Future<void> writeCsrfToken(String value) =>
      _storage.write(key: _csrfKey, value: value);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _cookieKey);
    await _storage.delete(key: _csrfKey);
  }
}
