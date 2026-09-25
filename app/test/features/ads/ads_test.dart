import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/data/sources/session_store.dart';
import 'package:lastreel/domain/models/entitlement.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_export.dart';

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

    AppHarness launchedBefore(int launches, {FakeEntitlementRepository? plan}) =>
        AppHarness(session: InMemorySessionStore(const SessionState(), launches), plan: plan);

    testWidgets('shows after a real break once the first three launches are past', (tester) async {
      final app = launchedBefore(3);
      await app.pump(tester);
      expect(app.ads.appOpenShown, 0, reason: 'never on a cold start');

      await leaveAndReturn(tester, app, const Duration(minutes: 2));
      expect(app.ads.appOpenShown, 1);
    });

    testWidgets('never in the first three launches', (tester) async {
      final app = launchedBefore(2); // this is launch 3
      await app.pump(tester);
      await leaveAndReturn(tester, app, const Duration(minutes: 2));
      expect(app.ads.appOpenShown, 0);
    });

    testWidgets('not after a short trip away (share sheet, a permission prompt)', (tester) async {
      final app = launchedBefore(10);
      await app.pump(tester);
      await leaveAndReturn(tester, app, const Duration(seconds: 5));
      expect(app.ads.appOpenShown, 0);
    });

    testWidgets('never on Pro', (tester) async {
      final app = launchedBefore(10, plan: FakeEntitlementRepository(const Entitlement.pro(period: BillingPeriod.monthly)));
      await app.pump(tester);
      await leaveAndReturn(tester, app, const Duration(minutes: 2));
      expect(app.ads.appOpenShown, 0);
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
}
