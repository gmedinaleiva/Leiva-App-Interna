import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:leiva_app_interna/main.dart';

void main() {
  testWidgets('la demo inicia sesión y muestra los accesos', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const LeivaApp());

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(
      find.text('Demo visual · Sin conexión a datos reales'),
      findsOneWidget,
    );

    final loginButton = find.byKey(const Key('loginButton'));
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Hola, Gustavo'), findsOneWidget);
    expect(find.text('Proveedores'), findsOneWidget);
    expect(find.text('Subproductos'), findsOneWidget);
  });
}
