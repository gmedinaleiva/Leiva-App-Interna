import 'package:flutter_test/flutter_test.dart';
import 'package:leiva_app_interna/core/security/idempotency_key.dart';
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
