import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/theme/ec_palette.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/ads/data/admob_ad_service.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_export.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  group('app-open ad on resume', () {
    /// Sends the app to the background for [away], then brings it back.
    Future<void> leaveAndReturn(WidgetTester tester, AppHarness app, Duration away) async {
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      app.now = app.now.add(away);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    }

    testWidgets('shows on the first return after 15 s away — never on a cold start', (tester) async {
      final app = AppHarness();
      await app.pump(tester);
      expect(app.ads.appOpenShown, 0, reason: 'never on open');

      await leaveAndReturn(tester, app, const Duration(seconds: 15));
      expect(app.ads.appOpenShown, 1);
    });

    testWidgets('not after a short trip away (share sheet, a permission prompt)', (tester) async {
      final app = AppHarness();
      await app.pump(tester);
      await leaveAndReturn(tester, app, const Duration(seconds: 10));
      expect(app.ads.appOpenShown, 0);
    });

    testWidgets('never on Pro', (tester) async {
      final app = AppHarness(plan: FakeEntitlementRepository(const Entitlement.pro(period: BillingPeriod.monthly)));
      await app.pump(tester);
      await leaveAndReturn(tester, app, const Duration(minutes: 2));
      expect(app.ads.appOpenShown, 0);
    });

    testWidgets('never over a render in progress', (tester) async {
      final app = AppHarness(
        projects: FakeProjectRepository(seed: [film()]),
        frames: FakeFrames(frames: 400),
      );
      await app.pump(tester);
      await tester.tap(find.text('The Long Way Down'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Render H.264'));
      await tester.pump(const Duration(milliseconds: 200));

      await leaveAndReturn(tester, app, const Duration(minutes: 2));
      expect(app.ads.appOpenShown, 0);

      // Let the render finish so no timers outlive the test.
      for (var i = 0; i < 500; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    });
  });

  group('7.4 ad privacy choices', () {
    Future<void> openPrivacy(WidgetTester tester, AppHarness app) async {
      await app.pump(tester);
      await tester.tap(find.bySemanticsLabel('Account').first);
      await tester.pumpAndSettle();
      final row = find.text('Privacy & data');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    testWidgets('appears only where consent rules require it', (tester) async {
      final app = AppHarness()..ads = FakeAdService(privacyRequired: true);
      await openPrivacy(tester, app);
      expect(find.text('Ad privacy choices'), findsOneWidget);
    });

    testWidgets('absent elsewhere', (tester) async {
      final app = AppHarness();
      await openPrivacy(tester, app);
      expect(find.text('Personalised ads'), findsOneWidget);
      expect(find.text('Ad privacy choices'), findsNothing);
    });
  });

  test('the native card gets the palette as #RRGGBB per role', () {
    final colours = nativeCardColours(EcPalette.light);
    expect(colours.keys, unorderedEquals(['surface', 'line', 'tint', 'ink', 'muted', 'onInk']));
    for (final v in colours.values) {
      expect(v, matches(RegExp(r'^#[0-9A-F]{6}$')));
    }
    final ink = EcPalette.light.ink.toARGB32() & 0xFFFFFF;
    expect(colours['ink'], '#${ink.toRadixString(16).padLeft(6, '0').toUpperCase()}');
  });
}
