import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';

enum AuthStatus {
  checkingSession,
  unauthenticated,
  submittingCredentials,
  authenticated,
  rateLimited,
  serviceUnavailable,
}

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthGateway _repository;

  AuthStatus status = AuthStatus.checkingSession;
  AuthSession? session;
  String? message;
  int? retryAfterSeconds;
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
      session = await _repository.restoreSession();
      status = session == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
    } catch (_) {
      status = AuthStatus.serviceUnavailable;
      message = 'No pudimos verificar la sesión. Revisá la conexión e intentá nuevamente.';
    }
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
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

  Future<void> logout() async {
    try {
      await _repository.logout();
    } finally {
      session = null;
      status = AuthStatus.unauthenticated;
      message = null;
      notifyListeners();
    }
  }

  Future<void> retrySessionCheck() async {
    status = AuthStatus.checkingSession;
    message = null;
    notifyListeners();
    await initialize();
  }
}
