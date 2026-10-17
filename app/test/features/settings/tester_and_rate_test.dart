import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';

void main() {
  Future<void> openSettings(WidgetTester tester, AppHarness app) async {
    await app.pump(tester);
    await tester.tap(find.bySemanticsLabel('Account').first);
    await tester.pumpAndSettle();
  }

  testWidgets('only a listed tester sees the switch', (tester) async {
    await openSettings(tester, AppHarness());
    expect(find.text('LastReel Pro (tester)'), findsNothing);
  });

  testWidgets('the tester switch makes this device read as Pro', (tester) async {
    final app = AppHarness(testerAllowed: true);
    await openSettings(tester, app);
    expect(find.text('Free plan'), findsOneWidget);

    await tester.tap(find.text('LastReel Pro (tester)'));
    await tester.pumpAndSettle();
    expect(app.testerMode.proOn, isTrue);
    expect(find.text('Free plan'), findsNothing);
    expect(find.text('LastReel Pro'), findsOneWidget);
  });

  testWidgets('Rate LastReel asks with the stars, even after the prompt came up', (tester) async {
    final app = AppHarness(); // the harness has already been asked
    await openSettings(tester, app);
    final rate = find.text('Rate LastReel');
    await tester.scrollUntilVisible(rate, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(rate);
    await tester.pumpAndSettle();
    expect(find.textContaining('Would you rate', findRichText: true), findsOneWidget);
    expect(find.byKey(const ValueKey('star-5')), findsOneWidget);
  });
}
