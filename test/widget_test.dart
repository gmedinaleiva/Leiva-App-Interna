import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leiva_app_interna/features/auth/data/auth_repository.dart';
import 'package:leiva_app_interna/features/auth/domain/auth_session.dart';
import 'package:leiva_app_interna/features/auth/presentation/auth_controller.dart';
import 'package:leiva_app_interna/main.dart';

void main() {
  testWidgets('autentica y muestra únicamente los módulos del piloto', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _FakeAuthGateway();
    final controller = AuthController(gateway);
    addTearDown(controller.dispose);

    await tester.pumpWidget(LeivaApp(authController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Conexión segura con el portal Leiva'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('usernameField')),
      'demo_sistemas_flota',
    );
    await tester.enterText(
      find.byKey(const Key('passwordField')),
      'password-never-logged',
    );
    final loginButton = find.byKey(const Key('loginButton'));
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(gateway.lastUsername, 'demo_sistemas_flota');
    expect(gateway.lastPassword, 'password-never-logged');
    expect(find.text('Hola, Usuario Piloto'), findsOneWidget);
    expect(find.text('Reservas de vehículos'), findsOneWidget);
    expect(find.text('Salas'), findsOneWidget);
    expect(find.text('Estacionamiento'), findsOneWidget);
    expect(find.text('Mis gastos'), findsOneWidget);
    expect(find.text('Proveedores'), findsNothing);
  });
}

class _FakeAuthGateway implements AuthGateway {
  String? lastUsername;
  String? lastPassword;

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
    required String deviceName,
  }) async {
    lastUsername = username;
    lastPassword = password;
    return AuthSession(
      authProvider: 'local_stage',
      user: const AuthUser(
        id: 1,
        username: 'demo_sistemas_flota',
        fullName: 'Usuario Piloto',
      ),
      capabilities: const AppCapabilities({}),
      csrfToken: 'test-csrf',
      idleExpiresAt: DateTime.utc(2026, 9, 18, 18),
      absoluteExpiresAt: DateTime.utc(2026, 9, 19, 18),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> logoutAll(String password) async {}
}
