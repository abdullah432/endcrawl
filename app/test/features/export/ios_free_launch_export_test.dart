import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/widgets/ec_ad_slot.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/ads/data/ad_service.dart';
import 'package:lastreel/features/export/models/export_models.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  late AppHarness app;

  setUp(() {
    app = AppHarness(
      iosFreeLaunch: true,
      projects: FakeProjectRepository(seed: [film()]),
    );
  });

  Future<void> tap(WidgetTester tester, String label) async {
    final finder = find.text(label).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openExport(WidgetTester tester) async {
    await app.pump(tester);
    await tap(tester, 'The Long Way Down');
    await tap(tester, 'Export');
  }

  Future<void> finishRender(WidgetTester tester) async {
    for (var frame = 0; frame < 80; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('standard export stays free and retains its sponsored ad', (
    tester,
  ) async {
    await openExport(tester);
    await tap(tester, 'Render H.264');
    await finishRender(tester);
    expect(app.encoder.started.single.codec, Codec.h264);
    expect(app.ads.rewardedShown, 0);
    expect(find.text('Save to Files'), findsOneWidget);
    expect(find.text('SPONSORED'), findsOneWidget);
    expect(find.text('Soundstripe — score your next cut'), findsOneWidget);
    expect(find.text('REMOVE ADS'), findsNothing);
    expect(app.plan.purchases, 0);
  }, variant: ios);

  testWidgets(
    'premium formats and 4K still need a reward; a reward buys exactly one render',
    (tester) async {
      await openExport(tester);
      await tap(tester, '4K UHD');
      expect(find.text('▶  Watch ad · render once'), findsOneWidget);
      expect(find.text('Go Pro · every render, no ads'), findsNothing);
      await tap(tester, '1920 HD');
      await tap(tester, 'ProRes 422 HQ');
      expect(find.text('Render ProRes 422 HQ'), findsNothing);
      expect(find.text('Go Pro · every render, no ads'), findsNothing);
      await tap(tester, '▶  Watch ad · render once');
      await finishRender(tester);
      expect(app.ads.rewardedShown, 1);
      expect(app.encoder.started.single.codec, Codec.prores422);
      expect(find.text('Save to Files'), findsOneWidget);
      expect(find.byType(EcAdSlot), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tap(tester, 'Export');
      await tap(tester, 'ProRes 422 HQ');
      expect(find.text('▶  Watch ad · render once'), findsOneWidget);
      expect(find.text('Render ProRes 422 HQ'), findsNothing);
      expect(app.plan.purchases, 0);
    },
    variant: ios,
  );

  for (final outcome in [
    RewardOutcome.closedEarly,
    RewardOutcome.unavailable,
  ]) {
    testWidgets('reward $outcome leaves premium export locked', (tester) async {
      app.ads.nextReward = outcome;
      await openExport(tester);
      await tap(tester, 'PNG sequence');
      await tap(tester, '▶  Watch ad · render once');
      expect(app.ads.rewardedShown, 1);
      expect(app.encoder.started, isEmpty);
      expect(find.text('▶  Watch ad · render once'), findsOneWidget);
      expect(find.text('Go Pro · every render, no ads'), findsNothing);
      expect(app.plan.purchases, 0);
    }, variant: ios);
  }

  testWidgets('existing Pro retains ad-free premium exports', (tester) async {
    app.plan = FakeEntitlementRepository(const Entitlement.pro());
    await openExport(tester);
    await tap(tester, 'ProRes 422 HQ');
    await tap(tester, '4K UHD');
    expect(find.text('Render ProRes 422 HQ'), findsOneWidget);
    expect(find.textContaining('Watch ad'), findsNothing);
    expect(find.byType(EcAdSlot), findsNothing);
    expect(app.ads.rewardedShown, 0);
  }, variant: ios);
}
