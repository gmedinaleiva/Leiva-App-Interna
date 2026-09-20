import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../../../core/security/local_access.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';

enum AuthStatus {
  checkingSession,
  unauthenticated,
  submittingCredentials,
  authenticated,
  biometricLocked,
  rateLimited,
  serviceUnavailable,
}

class AuthController extends ChangeNotifier {
  AuthController(
    this._repository, {
    this.localAccess = const DisabledLocalAccess(),
  });

  final AuthGateway _repository;
  final LocalAccessGateway localAccess;

  AuthStatus status = AuthStatus.checkingSession;
  AuthSession? session;
  String? message;
  int? retryAfterSeconds;
  String? rememberedUsername;
  bool biometricAvailable = false;
  bool biometricEnabled = false;
  Future<void> Function()? beforeLogout;
  bool _refreshingSession = false;

  void invalidateSession() {
    session = null;
    status = AuthStatus.unauthenticated;
    message = 'La sesión venció. Ingresá nuevamente.';
    notifyListeners();
  }

  Future<void> refreshSession() async {
    if (_refreshingSession || status != AuthStatus.authenticated) return;
    _refreshingSession = true;
    try {
      final refreshed = await _repository.restoreSession();
      if (refreshed == null) {
        invalidateSession();
      } else {
        session = refreshed;
        notifyListeners();
      }
    } finally {
      _refreshingSession = false;
    }
  }

  Future<void> initialize() async {
    try {
      rememberedUsername = await localAccess.readRememberedUsername();
      biometricEnabled = await localAccess.isBiometricEnabled();
      biometricAvailable = await localAccess.hasEnrolledBiometrics();
      session = await _repository.restoreSession();
      if (session == null) {
        status = AuthStatus.unauthenticated;
      } else {
        status = biometricEnabled
            ? AuthStatus.biometricLocked
            : AuthStatus.authenticated;
      }
    } catch (_) {
      status = AuthStatus.serviceUnavailable;
      message = 'No pudimos verificar la sesión. Revisá la conexión e intentá nuevamente.';
    }
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
    bool rememberUsername = false,
    bool enableBiometrics = false,
  }) async {
    status = AuthStatus.submittingCredentials;
    message = null;
    retryAfterSeconds = null;
    notifyListeners();
    try {
      final clientPlatform = switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'ios',
        _ => 'android',
      };
      session = await _repository.login(
        username: username.trim(),
        password: password,
        deviceName: clientPlatform == 'ios'
            ? 'Leiva App iOS'
            : 'Leiva App Android',
        clientPlatform: clientPlatform,
      );
      final normalizedUsername = username.trim();
      await localAccess.rememberUsername(
        rememberUsername ? normalizedUsername : null,
      );
      rememberedUsername = rememberUsername ? normalizedUsername : null;
      if (enableBiometrics && biometricAvailable) {
        final verified =
            biometricEnabled ||
            await localAccess.authenticate(
              'Confirmá tu identidad para activar el acceso con huella.',
            );
        biometricEnabled = verified;
        await localAccess.setBiometricEnabled(verified);
      } else if (!enableBiometrics) {
        biometricEnabled = false;
        await localAccess.setBiometricEnabled(false);
      }
      status = AuthStatus.authenticated;
    } on ApiFailure catch (error) {
      if (error.statusCode == 429) {
        status = AuthStatus.rateLimited;
        retryAfterSeconds = error.retryAfterSeconds;
        message = 'Se alcanzó el límite temporal de intentos. Esperá antes de volver a probar.';
      } else if (error.statusCode == 401) {
        status = AuthStatus.unauthenticated;
        message = 'No pudimos iniciar sesión con esos datos.';
      } else {
        status = AuthStatus.serviceUnavailable;
        message = 'El servicio no está disponible en este momento.';
      }
    } on DioException {
      status = AuthStatus.serviceUnavailable;
      message = 'No pudimos comunicarnos con el portal de forma segura.';
    } on FormatException {
      status = AuthStatus.serviceUnavailable;
      message = 'El portal devolvió una respuesta inesperada.';
    }
    notifyListeners();
  }

  Future<void> unlockWithBiometrics() async {
    if (status != AuthStatus.biometricLocked || !biometricAvailable) return;
    message = null;
    notifyListeners();
    final unlocked = await localAccess.authenticate(
      'Usá tu huella para ingresar a Leiva Interna.',
    );
    if (unlocked) {
      status = AuthStatus.authenticated;
    } else {
      message = 'No se pudo validar la huella. Intentá nuevamente.';
    }
    notifyListeners();
  }

  Future<bool> configureBiometricUnlock(bool enabled) async {
    if (enabled) {
      if (!biometricAvailable) return false;
      final verified = await localAccess.authenticate(
        'Confirmá tu identidad para activar el acceso con huella.',
      );
      if (!verified) return false;
    }
    await localAccess.setBiometricEnabled(enabled);
    biometricEnabled = enabled;
    notifyListeners();
    return true;
  }

  Future<void> usePasswordInstead() async {
    try {
      await _runBeforeLogout();
      await _repository.logout();
    } finally {
      session = null;
      status = AuthStatus.unauthenticated;
      message = null;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _runBeforeLogout();
      await _repository.logout();
    } finally {
      session = null;
      status = AuthStatus.unauthenticated;
      message = null;
      notifyListeners();
    }
  }

  Future<void> _runBeforeLogout() async {
    try {
      await beforeLogout?.call();
    } catch (_) {
      // El cierre de la sesión del portal debe continuar aunque falle la baja push.
    }
  }

  Future<void> retrySessionCheck() async {
    status = AuthStatus.checkingSession;
    message = null;
    notifyListeners();
    await initialize();
  }
}
