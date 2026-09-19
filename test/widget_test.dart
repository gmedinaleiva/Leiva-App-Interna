import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leiva_app_interna/features/auth/data/auth_repository.dart';
import 'package:leiva_app_interna/features/auth/domain/auth_session.dart';
import 'package:leiva_app_interna/features/auth/presentation/auth_controller.dart';
import 'package:leiva_app_interna/features/rooms/data/rooms_repository.dart';
import 'package:leiva_app_interna/features/rooms/domain/room_models.dart';
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

  testWidgets('habilita Salas según las capacidades de la sesión', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _FakeAuthGateway(
      capabilities: const AppCapabilities({
        'room_reservations': {'view': true, 'create': true},
      }),
    );
    final controller = AuthController(auth);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      LeivaApp(authController: controller, roomsGateway: _FakeRoomsGateway()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('usernameField')), 'piloto');
    await tester.enterText(find.byKey(const Key('passwordField')), 'secreto');
    await tester.ensureVisible(find.byKey(const Key('loginButton')));
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();

    expect(find.text('Disponible'), findsOneWidget);
    await tester.tap(find.text('Salas'));
    await tester.pumpAndSettle();

    expect(find.text('Reservas de salas'), findsOneWidget);
    expect(find.text('Todavía no tenés reservas'), findsOneWidget);
    expect(
      find.byKey(const Key('createRoomReservationButton')),
      findsOneWidget,
    );
  });
}

class _FakeAuthGateway implements AuthGateway {
  _FakeAuthGateway({this.capabilities = const AppCapabilities({})});

  final AppCapabilities capabilities;
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
      capabilities: capabilities,
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

class _FakeRoomsGateway implements RoomsGateway {
  @override
  Future<List<RoomBranch>> branches() async => const [
    RoomBranch(id: 1, code: 'CASA', name: 'Casa Central'),
  ];

  @override
  Future<List<RoomReservation>> reservations({
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  Future<List<RoomAvailability>> availability({
    required int branchId,
    required DateTime from,
    required DateTime to,
  }) async => const [
    RoomAvailability(
      roomId: 1,
      code: 'S1',
      name: 'Sala 1',
      capacity: 8,
      available: true,
    ),
  ];

  @override
  Future<RoomReservation> cancel(int reservationId, {String? reason}) =>
      throw UnimplementedError();

  @override
  Future<RoomReservation> create(RoomReservationDraft draft) =>
      throw UnimplementedError();

  @override
  Future<List<MeetingRoom>> rooms(int branchId) async => const [];
}
