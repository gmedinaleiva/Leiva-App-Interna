import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leiva_app_interna/features/expenses/data/expenses_repository.dart';
import 'package:leiva_app_interna/features/expenses/domain/expense_models.dart';
import 'package:leiva_app_interna/features/expenses/presentation/expenses_screen.dart';

class Gateway implements ExpensesGateway {
  bool blocked = false;
  int sends = 0;
  @override
  Future<ExpenseRecord> record(int id) async => ExpenseRecord.fromJson({
    'id': id,
    'type': 'travel_expense',
    'status': 'personal_expense_draft',
    'status_label': 'Borrador personal',
    'title': 'Peaje',
    'period': {
      'id': 10,
      'status': 'open',
      'status_label': 'Abierta',
      'label': 'Octubre',
      'document_count': 2,
      'consumed_amount': 55000,
      'funding_mode': 'reimbursement',
    },
    'actions': {'edit': true, 'cancel': true, 'submit_period': !blocked},
    'fuel_evidence': blocked ? <String, dynamic>{'status': 'pending'} : null,
    'period_pending_controls': blocked
        ? [
            {
              'id': id,
              'title': 'Peaje',
              'reasons': ['Esperar control fiscal.'],
            },
          ]
        : [],
  });
  @override
  Future<ExpensePeriod> submitPeriod(int id) async {
    sends++;
    return ExpensePeriod.fromJson({'id': id, 'status': 'submitted'});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'draft exposes correction and cancellation; sending requires confirmation',
    (tester) async {
      final gateway = Gateway();
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseRecordScreen(gateway: gateway, documentId: 567),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Editar datos'), findsOneWidget);
      expect(find.text('Anular borrador'), findsOneWidget);
      await tester.tap(find.text('Enviar rendición a Gerencia'));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 comprobante(s), por'), findsOneWidget);
      expect(gateway.sends, 0);
      await tester.tap(find.text('Enviar rendición'));
      await tester.pumpAndSettle();
      expect(gateway.sends, 1);
    },
  );
  testWidgets('pending controls explain why sending is unavailable', (
    tester,
  ) async {
    final gateway = Gateway()..blocked = true;
    await tester.pumpWidget(
      MaterialApp(home: ExpenseRecordScreen(gateway: gateway, documentId: 567)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Esperar control fiscal.'), findsOneWidget);
    expect(find.text('Enviar rendición a Gerencia'), findsNothing);
    expect(
      find.text('Resolver control: Validar evidencia GeoSat'),
      findsOneWidget,
    );
    expect(find.text('Editar datos'), findsOneWidget);
  });
}
