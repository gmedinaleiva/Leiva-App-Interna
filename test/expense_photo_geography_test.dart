import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leiva_app_interna/features/expenses/data/expenses_api.dart';
import 'package:leiva_app_interna/features/expenses/data/expenses_repository.dart';
import 'package:leiva_app_interna/features/expenses/domain/expense_models.dart';
import 'package:leiva_app_interna/features/expenses/presentation/geography_fields.dart';
import 'package:leiva_app_interna/features/vehicles/domain/vehicle_models.dart';
import 'package:leiva_app_interna/features/vehicles/data/vehicles_repository.dart';
import 'package:leiva_app_interna/features/vehicles/presentation/vehicles_screen.dart';

void main() {
  for (final kind in ['unknown', 'fiscal']) {
    test('photo bytes reach upload with $kind and unusable path', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/'));
      var sent = false;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final form = options.data as FormData;
            expect(Map.fromEntries(form.fields)['fiscal_kind'], kind);
            expect(options.headers['Idempotency-Key'], 'test-photo');
            final bytes = await form.files.single.value
                .finalize()
                .expand((e) => e)
                .toList();
            expect(bytes, [255, 216, 255, 217]);
            sent = true;
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'data': {
                    'id': 1,
                    'type': 'travel_expense',
                    'status': 'pending',
                  },
                },
              ),
            );
          },
        ),
      );
      await ExpensesApi(dio).upload(
        ExpenseUploadDraft(
          idempotencyKey: 'test-photo',
          section: 'travel',
          expenseDate: DateTime(2026, 10, 29),
          amount: 100,
          rubric: 'Combustible',
          fileName: 'photo.jpg',
          filePath: 'blob:unusable-camera-path',
          fileBytes: Uint8List.fromList([255, 216, 255, 217]),
          fiscalKind: kind,
        ),
      );
      expect(sent, isTrue);
    });
  }
  test('trajectory indicator does not require events', () {
    final row = VehicleReservation.fromJson({
      'id': 1,
      'status': 'cerrada',
      'starts_at': '2026-10-01T10:00:00Z',
      'ends_at': '2026-10-01T11:00:00Z',
      'has_trajectory': true,
    });
    expect(row.trajectoryLabel, 'Trayectoria disponible');
  });
  testWidgets('trip without events or GPS still shows reservation detail', (
    tester,
  ) async {
    final gateway = _EmptyTripGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: VehicleTripScreen(gateway: gateway, reservation: gateway.row),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Datos del viaje'), findsOneWidget);
    expect(find.text('No pudimos completar la operación.'), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('No hay posiciones GPS'),
      180,
    );
    expect(find.textContaining('No hay posiciones GPS'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'province search filters cities and changing province clears city',
    (tester) async {
      final province = TextEditingController(), city = TextEditingController();
      final gateway = _GeographyGateway();
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: form,
              child: GeographyFields(
                gateway: gateway,
                province: province,
                city: city,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'cord');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Córdoba').last);
      await tester.pumpAndSettle();
      expect(gateway.selectedProvince, 2);
      await tester.enterText(find.byType(TextFormField).last, 'villa');
      await tester.pumpAndSettle();
      expect(find.text('Villa María'), findsOneWidget);
      expect(find.text('Rosario'), findsNothing);
      await tester.tap(find.text('Villa María'));
      await tester.pumpAndSettle();
      expect(form.currentState!.validate(), isTrue);
      await tester.enterText(find.byType(TextFormField).first, 'santa');
      await tester.pumpAndSettle();
      expect(city.text, isEmpty);
      await tester.tap(find.text('Santa Fe').last);
      await tester.pumpAndSettle();
      expect(gateway.selectedProvince, 1);
      await tester.enterText(find.byType(TextFormField).last, 'Inventada');
      expect(form.currentState!.validate(), isFalse);
      await tester.pumpWidget(const SizedBox());
      province.dispose();
      city.dispose();
    },
  );
}

class _GeographyGateway implements ExpensesGateway {
  int? selectedProvince;
  @override
  Future<List<GeographicOption>> provinces() async => const [
    GeographicOption(id: 1, name: 'Santa Fe'),
    GeographicOption(id: 2, name: 'Córdoba'),
  ];
  @override
  Future<List<GeographicOption>> localities(int provinceId) async {
    selectedProvince = provinceId;
    return [
      GeographicOption(
        id: provinceId,
        name: provinceId == 1 ? 'Rosario' : 'Villa María',
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyTripGateway implements VehiclesGateway {
  final row = VehicleReservation(
    id: 1,
    status: 'cerrada',
    startsAt: DateTime(2026, 10, 1),
    endsAt: DateTime(2026, 10, 2),
    hasTrajectory: false,
  );
  @override
  Future<VehicleReservation> reservation(int id) async => row;
  @override
  Future<VehicleTripView> trip(int id, {required bool live}) async =>
      const VehicleTripView(
        status: 'cerrada',
        summary: {},
        points: [],
        events: [],
        live: {},
        fuel: {},
      );
  @override
  Future<List<VehicleNotice>> notices({int? reservationId}) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
