import 'package:flutter_test/flutter_test.dart';
import 'package:leiva_app_interna/core/security/idempotency_key.dart';
import 'package:leiva_app_interna/core/security/local_access.dart';
import 'package:leiva_app_interna/features/auth/data/auth_repository.dart';
import 'package:leiva_app_interna/features/auth/domain/auth_session.dart';
import 'package:leiva_app_interna/features/auth/presentation/auth_controller.dart';

void main() {
  test('genera UUID v4 únicos para idempotencia', () {
    final values = List.generate(100, (_) => newIdempotencyKey());
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(values.toSet(), hasLength(values.length));
    expect(values.every(uuidV4.hasMatch), isTrue);
  });

  test('invalidar sesión elimina identidad y vuelve al login', () {
    final controller = AuthController(_NeverCalledAuthGateway())
      ..session = _session
      ..status = AuthStatus.authenticated;

    controller.invalidateSession();

    expect(controller.session, isNull);
    expect(controller.status, AuthStatus.unauthenticated);
    expect(controller.message, contains('sesión venció'));
    controller.dispose();
  });

  test('las capacidades se evalúan por acción', () {
    const capabilities = AppCapabilities({
      'my_expenses': {'view': true, 'travel': false},
    });

    expect(capabilities.allows('my_expenses', 'view'), isTrue);
    expect(capabilities.allows('my_expenses', 'travel'), isFalse);
    expect(capabilities.allows('vehicle_reservations', 'view'), isFalse);
  });

  test('una sesión recordada exige huella antes de mostrar la app', () async {
    final localAccess = _FakeLocalAccess(
      rememberedUsername: 'piloto',
      biometricEnabled: true,
      biometricAvailable: true,
      authenticationResult: true,
    );
    final controller = AuthController(
      _RestoredAuthGateway(),
      localAccess: localAccess,
    );

    await controller.initialize();
    expect(controller.rememberedUsername, 'piloto');
    expect(controller.status, AuthStatus.biometricLocked);

    await controller.unlockWithBiometrics();
    expect(controller.status, AuthStatus.authenticated);
    expect(localAccess.authenticationCalls, 1);
    controller.dispose();
  });

  test(
    'recordar usuario nunca entrega la contraseña al almacén local',
    () async {
      final localAccess = _FakeLocalAccess(biometricAvailable: false);
      final controller = AuthController(
        _RestoredAuthGateway(restore: false),
        localAccess: localAccess,
      );
      await controller.initialize();

      await controller.login(
        username: ' piloto ',
        password: 'secreto-solo-para-api',
        rememberUsername: true,
      );

      expect(localAccess.savedUsername, 'piloto');
      expect(localAccess.savedUsername, isNot(contains('secreto')));
      expect(controller.status, AuthStatus.authenticated);
      controller.dispose();
    },
  );
}

final _session = AuthSession(
  authProvider: 'local_stage',
  user: const AuthUser(id: 1, username: 'piloto'),
  capabilities: const AppCapabilities({}),
  csrfToken: 'csrf-de-prueba',
  idleExpiresAt: DateTime.utc(2026, 9, 19, 12),
  absoluteExpiresAt: DateTime.utc(2026, 9, 19, 18),
);

class _NeverCalledAuthGateway implements AuthGateway {
  @override
  Future<AuthSession?> restoreSession() => throw UnimplementedError();

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required String deviceName,
    required String clientPlatform,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> logoutAll(String password) => throw UnimplementedError();
}

class _RestoredAuthGateway implements AuthGateway {
  _RestoredAuthGateway({this.restore = true});

  final bool restore;

  @override
  Future<AuthSession?> restoreSession() async => restore ? _session : null;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required String deviceName,
    required String clientPlatform,
  }) async => _session;

  @override
  Future<void> logout() async {}

  @override
  Future<void> logoutAll(String password) async {}
}

class _FakeLocalAccess implements LocalAccessGateway {
  _FakeLocalAccess({
    this.rememberedUsername,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.authenticationResult = false,
  });

  final String? rememberedUsername;
  bool biometricEnabled;
  final bool biometricAvailable;
  final bool authenticationResult;
  String? savedUsername;
  int authenticationCalls = 0;

  @override
  Future<bool> authenticate(String reason) async {
    authenticationCalls++;
    return authenticationResult;
  }

  @override
  Future<bool> hasEnrolledBiometrics() async => biometricAvailable;

  @override
  Future<bool> isBiometricEnabled() async => biometricEnabled;

  @override
  Future<String?> readRememberedUsername() async => rememberedUsername;

  @override
  Future<void> rememberUsername(String? username) async {
    savedUsername = username;
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    biometricEnabled = enabled;
  }
}
