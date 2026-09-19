import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leiva_app_interna/leiva_prelogin/leiva_prelogin.dart';

void main() {
  testWidgets(
    'Login ready at 4.5s, Tech remains mounted, no duplicate callback',
    (tester) async {
      var ready = 0;
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LeivaPrelogin(
            onLoginReady: () => ready++,
            loginBuilder: (_) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const ValueKey('actual-login'),
                  onPressed: () => taps++,
                  child: const Text('Login real'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3900));
      expect(ready, 0);
      final before = tester.element(
        find.byKey(const ValueKey('leiva-tech-badge')),
      );
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
      expect(ready, 1);
      expect(
        tester.element(find.byKey(const ValueKey('leiva-tech-badge'))),
        same(before),
      );
      await tester.tap(find.byKey(const ValueKey('actual-login')));
      expect(taps, 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(ready, 1);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Skip intro exposes real login immediately', (tester) async {
    var ready = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LeivaPrelogin(
          skipIntro: true,
          onLoginReady: () => ready++,
          loginBuilder: (_) => const Scaffold(body: Text('Login inmediato')),
        ),
      ),
    );
    await tester.pump();
    expect(ready, 1);
    expect(find.text('Login inmediato'), findsOneWidget);
    expect(find.byKey(const ValueKey('leiva-tech-badge')), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El prelogin cubre todo el viewport vertical', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: LeivaPrelogin(
          loginBuilder: (_) => const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(LeivaPrelogin)), const Size(360, 800));
    expect(tester.takeException(), isNull);
  });
}
