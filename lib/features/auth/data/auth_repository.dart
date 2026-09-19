import '../../../core/network/api_error.dart';
import '../../../core/security/secure_session_store.dart';
import '../domain/auth_session.dart';
import 'auth_api.dart';

abstract interface class AuthGateway {
  Future<AuthSession?> restoreSession();

  Future<AuthSession> login({
    required String username,
    required String password,
    required String deviceName,
    required String clientPlatform,
  });

  Future<void> logout();

  Future<void> logoutAll(String password);
}

class AuthRepository implements AuthGateway {
  const AuthRepository(this._api, this._sessionStore);

  final AuthApi _api;
  final SessionStore _sessionStore;

  @override
  Future<AuthSession?> restoreSession() async {
    final cookie = await _sessionStore.readSessionCookie();
    if (cookie == null || cookie.isEmpty) return null;
    try {
      final session = await _api.me();
      final csrf = session.csrfToken.isNotEmpty
          ? session.csrfToken
          : await _api.rotateCsrf();
      await _sessionStore.writeCsrfToken(csrf);
      return session;
    } on ApiFailure catch (error) {
      if (error.statusCode == 401) {
        await _sessionStore.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required String deviceName,
    required String clientPlatform,
  }) async {
    final session = await _api.login(
      username: username,
      password: password,
      deviceName: deviceName,
      clientPlatform: clientPlatform,
    );
    final cookie = await _sessionStore.readSessionCookie();
    if (cookie == null || cookie.isEmpty) {
      await _sessionStore.clear();
      throw const FormatException('La API no emitió una sesión utilizable.');
    }
    await _sessionStore.writeCsrfToken(session.csrfToken);
    return session;
  }

  @override
  Future<void> logout() async {
    try {
      await _api.logout();
    } finally {
      await _sessionStore.clear();
    }
  }

  @override
  Future<void> logoutAll(String password) async {
    await _api.logoutAll(password);
    await _sessionStore.clear();
  }
}
