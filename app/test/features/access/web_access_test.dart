import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/config/billing_config.dart';
import 'package:lastreel/core/widgets/ec_button.dart';
import 'package:lastreel/data/repositories/claims_entitlement_repository.dart';
import 'package:lastreel/domain/models/entitlement.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

const desktop = Size(1440, 900);
const tablet = Size(1194, 834);

void main() {
  group('Pro from the sign-in token', () {
    test('Pro only when the server-set claim lists the Pro entitlement', () {
      expect(
        entitlementFromClaims({
          BillingConfig.entitlementsClaim: [BillingConfig.entitlementId],
        }).isPro,
        isTrue,
      );
      expect(entitlementFromClaims({BillingConfig.entitlementsClaim: <String>[]}).isPro, isFalse);
      expect(entitlementFromClaims({BillingConfig.entitlementsClaim: BillingConfig.entitlementId}).isPro, isFalse);
      expect(
        entitlementFromClaims({
          'other': [BillingConfig.entitlementId],
        }).isPro,
        isFalse,
      );
      expect(entitlementFromClaims(null).isPro, isFalse);
    });
  });

  group('web without Pro', () {
    late AppHarness app;

    setUp(() => app = AppHarness(projects: FakeProjectRepository(seed: [film()]), web: true));

    Future<void> preview(WidgetTester tester) async {
      await app.pump(tester, size: desktop);
      await tester.tap(find.text('Preview the app first'));
      await tester.pumpAndSettle();
    }

    testWidgets('signs in to how to get Pro — the mobile subscription handoff', (tester) async {
      await app.pump(tester, size: desktop);
      expect(find.text('Subscribe in the mobile app.'), findsOneWidget);
      expect(find.text('I’ve subscribed — check access'), findsOneWidget);
    });

    testWidgets('checking access without a subscription says so and stays locked', (tester) async {
      await app.pump(tester, size: desktop);
      await tester.tap(find.text('I’ve subscribed — check access'));
      await tester.pumpAndSettle();
      expect(find.text('No Pro subscription on this account.'), findsOneWidget);
    });

    testWidgets('a subscription bought on the phone unlocks the workspace', (tester) async {
      await app.pump(tester, size: desktop);
      app.plan.entitlement = const Entitlement.pro(period: BillingPeriod.yearly);
      await tester.tap(find.text('I’ve subscribed — check access'));
      await tester.pumpAndSettle();
      expect(find.text('No Pro subscription on this account.'), findsNothing);
      expect(find.text('You’re previewing LastReel on the web.'), findsNothing);
    });

    testWidgets('the preview opens projects but locks starting new ones', (tester) async {
      await preview(tester);
      expect(find.text('You’re previewing LastReel on the web.'), findsOneWidget);

      await tester.tap(find.text('New project').first);
      await tester.pumpAndSettle();
      expect(find.text('Starting projects in the browser needs Pro.'), findsOneWidget);
      await tester.tap(find.text('Keep previewing'));
      await tester.pumpAndSettle();
      expect(app.projects.projects, hasLength(1));
    });

    testWidgets('the preview editor is read-only: no adding, and export is locked', (tester) async {
      await preview(tester);
      await tester.tap(find.text('The Long Way Down').first);
      await tester.pumpAndSettle();
      final blocks = app.projects.projects.values.single.blocks.length;

      expect(find.widgetWithText(EcButton, 'Block'), findsNothing);
      expect(find.widgetWithText(EcButton, 'Paste'), findsNothing);

      await tester.tap(find.text('Export').first);
      await tester.pumpAndSettle();
      expect(find.text('Exporting from the browser needs Pro.'), findsOneWidget);
      await tester.tap(find.text('Keep previewing'));
      await tester.pumpAndSettle();

      expect(app.encoder.started, isEmpty);
      expect(app.projects.projects.values.single.blocks, hasLength(blocks));
    });
  });

  group('web with Pro', () {
    testWidgets('opens straight into the workspace, where everything works', (tester) async {
      final app = AppHarness(
        projects: FakeProjectRepository(seed: [film()]),
        plan: FakeEntitlementRepository(const Entitlement.pro(period: BillingPeriod.yearly)),
        web: true,
      );
      await app.pump(tester, size: desktop);
      expect(find.text('Subscribe in the mobile app.'), findsNothing);
      expect(find.text('You’re previewing LastReel on the web.'), findsNothing);

      await tester.tap(find.text('New project').first);
      await tester.pumpAndSettle();
      expect(find.text('Starting projects in the browser needs Pro.'), findsNothing);
      expect(find.text('Create project'), findsOneWidget);
    });
  });

  group('the mobile apps', () {
    testWidgets('keep their Free rules on a tablet — no web preview, no lock', (tester) async {
      final app = AppHarness(projects: FakeProjectRepository(seed: [film()]));
      await app.pump(tester, size: tablet);
      expect(find.text('You’re previewing LastReel on the web.'), findsNothing);

      await tester.tap(find.text('The Long Way Down').first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(EcButton, 'Block'), findsOneWidget);
    });
  });
}
