import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leiva_app_interna/features/auth/data/auth_repository.dart';
import 'package:leiva_app_interna/features/auth/domain/auth_session.dart';
import 'package:leiva_app_interna/features/auth/presentation/auth_controller.dart';
import 'package:leiva_app_interna/features/expenses/data/expenses_repository.dart';
import 'package:leiva_app_interna/features/expenses/domain/expense_models.dart';
import 'package:leiva_app_interna/features/parking/data/parking_repository.dart';
import 'package:leiva_app_interna/features/parking/domain/parking_models.dart';
import 'package:leiva_app_interna/features/rooms/data/rooms_repository.dart';
import 'package:leiva_app_interna/features/rooms/domain/room_models.dart';
import 'package:leiva_app_interna/features/vehicles/data/vehicles_repository.dart';
import 'package:leiva_app_interna/features/vehicles/domain/vehicle_models.dart';
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

    await tester.pumpWidget(
      LeivaApp(authController: controller, skipPrelogin: true),
    );
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
      LeivaApp(
        authController: controller,
        roomsGateway: _FakeRoomsGateway(),
        skipPrelogin: true,
      ),
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

  testWidgets('habilita y abre los módulos integrales autorizados', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _FakeAuthGateway(
      capabilities: const AppCapabilities({
        'vehicle_reservations': {'view': true, 'create': true},
        'room_reservations': {'view': true, 'create': true},
        'parking_requests': {'view': true, 'create': true},
        'my_expenses': {
          'view': true,
          'upload': true,
          'benefits': true,
          'travel': true,
          'advances': true,
        },
      }),
    );
    final controller = AuthController(auth);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      LeivaApp(
        authController: controller,
        roomsGateway: _FakeRoomsGateway(),
        vehiclesGateway: _FakeVehiclesGateway(),
        parkingGateway: _FakeParkingGateway(),
        expensesGateway: _FakeExpensesGateway(),
        skipPrelogin: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('usernameField')), 'piloto');
    await tester.enterText(find.byKey(const Key('passwordField')), 'secreto');
    await tester.ensureVisible(find.byKey(const Key('loginButton')));
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();

    expect(find.text('Disponible'), findsNWidgets(4));

    await tester.tap(find.text('Reservas de vehículos'));
    await tester.pumpAndSettle();
    expect(
      find.text('Todavía no tenés reservas de vehículos.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Estacionamiento'));
    await tester.tap(find.text('Estacionamiento'));
    await tester.pumpAndSettle();
    expect(
      find.text('Todavía no tenés solicitudes de estacionamiento.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Módulos').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Herramientas habilitadas para tu cuenta.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Gestiones').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Iniciá o consultá una gestión desde su módulo.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    expect(find.text('4 de 4 módulos habilitados'), findsOneWidget);

    await tester.tap(find.text('Inicio').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mis gastos'));
    await tester.tap(find.text('Mis gastos'));
    await tester.pumpAndSettle();
    expect(find.text('No tenés comprobantes cargados.'), findsOneWidget);
    expect(find.byKey(const Key('createExpenseButton')), findsOneWidget);
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
    required String clientPlatform,
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
  Future<RoomReservation> detail(int reservationId) =>
      throw UnimplementedError();

  @override
  Future<VisitorParkingOptions> visitorParkingOptions(
    int reservationId, {
    required String vehicleType,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> createVisitorParking(
    int reservationId,
    VisitorParkingDraft draft,
  ) => throw UnimplementedError();

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

class _FakeVehiclesGateway implements VehiclesGateway {
  @override
  Future<List<VehicleOption>> available({
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  Future<List<VehicleReservation>> reservations() async => const [];

  @override
  Future<VehicleReservation> action(
    int reservationId,
    String action, {
    String? notes,
  }) => throw UnimplementedError();

  @override
  Future<VehicleReservation> create(VehicleReservationDraft draft) =>
      throw UnimplementedError();

  @override
  Future<VehicleReservation> extend(
    int reservationId,
    DateTime endsAt, {
    String? notes,
  }) => throw UnimplementedError();

  @override
  Future<List<VehicleNotice>> notices({int? reservationId}) async => const [];

  @override
  Future<VehicleTripView> trip(int reservationId, {required bool live}) =>
      throw UnimplementedError();
}

class _FakeParkingGateway implements ParkingGateway {
  @override
  Future<List<ParkingBranch>> branches() async => const [
    ParkingBranch(id: 1, name: 'Casa Central'),
  ];

  @override
  Future<List<ParkingBay>> bays({
    required int branchId,
    required DateTime from,
    required DateTime to,
    required String vehicleType,
  }) async => const [];

  @override
  Future<List<ParkingRequest>> requests() async => const [];

  @override
  Future<ParkingRequest> cancel(int requestId) => throw UnimplementedError();

  @override
  Future<ParkingRequest> create(ParkingRequestDraft draft) =>
      throw UnimplementedError();
}

class _FakeExpensesGateway implements ExpensesGateway {
  @override
  Future<ExpensePeriod> confirmReceipt(
    int periodId,
    ExpenseReceiptDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<ExpensePeriod> createTravelAdvance(TravelAdvanceDraft draft) =>
      throw UnimplementedError();

  @override
  Future<ExpenseFile> file(int documentId) => throw UnimplementedError();

  @override
  Future<ExpenseRecord> record(int documentId) => throw UnimplementedError();

  @override
  Future<ExpenseRecord> resubmit(int documentId) => throw UnimplementedError();

  @override
  Future<ExpenseRecord> saveFuelStatement(int documentId, String statement) =>
      throw UnimplementedError();

  @override
  Future<ExpensePeriod> submitPeriod(int periodId) =>
      throw UnimplementedError();

  @override
  Future<ExpenseRecord> validateFuel(int documentId) =>
      throw UnimplementedError();

  @override
  Future<ExpenseDashboard> dashboard() async => const ExpenseDashboard(
    capabilities: {
      'view': true,
      'upload': true,
      'benefits': true,
      'travel': true,
    },
    periods: [],
    records: [],
    alerts: [],
  );

  @override
  Future<ExpenseRubrics> rubrics() async =>
      const ExpenseRubrics(travel: ['Combustible'], benefits: ['Beneficio']);

  @override
  Future<ExpenseRecord> upload(ExpenseUploadDraft draft) =>
      throw UnimplementedError();

  @override
  Future<ExpenseRecord> updateRecord(
    int documentId,
    ExpenseUpdateDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<ExpensePeriod> requestAdvanceCorrection(
    int periodId,
    String observation,
  ) => throw UnimplementedError();
}
