import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/config/app_links.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/plan/screens/pro_sheet.dart';
import 'package:lastreel/features/settings/screens/settings_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';

void main() {
  Future<void> settings(
    WidgetTester tester,
    AppHarness app, {
    Size size = AppHarness.phone,
  }) async {
    await app.pump(tester, size: size);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Free always discovers Desktop & web in settings, even when the popup is off',
    (tester) async {
      final app = AppHarness();
      await settings(tester, app);
      final preview = find.text('Preview');
      await tester.ensureVisible(preview);
      expect(find.text('Desktop & web'), findsOneWidget);
      expect(
        find.text('Only with Pro. Take a look before you upgrade.'),
        findsOneWidget,
      );
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('on a big screen.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.text('Preview on the web'), findsOneWidget);
      expect(app.links.opened, isEmpty);
      await tester.ensureVisible(find.text('Preview on the web'));
      await tester.tap(find.text('Preview on the web'));
      await tester.pumpAndSettle();
      expect(app.links.opened, [AppLinks.webApp]);
      expect(app.desk.quietUntil, isNull);
      expect(app.desk.turnedOff, isTrue);
    },
  );

  testWidgets('Free can upgrade from the desktop preview sheet', (
    tester,
  ) async {
    final app = AppHarness();
    await settings(tester, app);
    await tester.ensureVisible(find.text('Preview'));
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Upgrade to Pro'));
    await tester.tap(find.text('Upgrade to Pro'));
    await tester.pumpAndSettle();
    expect(find.byType(ProSheet), findsOneWidget);
    expect(
      find.textContaining('on a big screen.', findRichText: true),
      findsNothing,
    );
    expect(app.links.opened, isEmpty);
    expect(app.desk.quietUntil, isNull);
    expect(app.desk.turnedOff, isTrue);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Pro can open the existing send-link sheet without changing the popup schedule',
    (tester) async {
      final app = AppHarness(
        plan: FakeEntitlementRepository(const Entitlement.pro()),
      );
      await settings(tester, app);
      await tester.ensureVisible(find.text('Send the link'));
      expect(find.text('Included with Pro'), findsOneWidget);
      await tester.tap(find.text('Send the link'));
      await tester.pumpAndSettle();
      expect(find.text('Email me the link'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(app.desk.quietUntil, isNull);
      expect(app.desk.turnedOff, isTrue);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(834, 1194),
    const Size(1440, 900),
  ]) {
    testWidgets('the card fits enlarged text at $size', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await settings(tester, AppHarness(), size: size);
      await tester.ensureVisible(find.text('Preview'));
      expect(find.text('Desktop & web'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
