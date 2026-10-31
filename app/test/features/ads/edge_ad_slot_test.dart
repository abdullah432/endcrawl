import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/ads/data/ad_service.dart';
import 'package:lastreel/features/ads/widgets/edge_ad_slot.dart';
import 'package:lastreel/features/ads/widgets/tablet_ad.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

const landscape = Size(1194, 834);
const portrait = Size(834, 1194);
const ipad13 = Size(1366, 1024);

void main() {
  AppHarness harness({Entitlement plan = const Entitlement.free()}) => AppHarness(
    projects: FakeProjectRepository(seed: [film()]),
    plan: FakeEntitlementRepository(plan),
  );

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  Iterable<(AdPlacement, AdSlotStyle)> requests(AppHarness app, AdPlacement placement) =>
      app.ads.requested.where((r) => r.$1 == placement);

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final size in [landscape, portrait, ipad13, AppHarness.phone]) {
      testWidgets('T3.1 / P3.1: the editor ad is the tablet’s, at its edge: $platform $size', (tester) async {
        final app = harness();
        await app.pump(tester, size: size);
        await tap(tester, 'The Long Way Down');
        final tablet = size.shortestSide >= 600;
        final editor = requests(app, AdPlacement.editor);
        expect(editor.isNotEmpty, tablet);
        if (tablet) {
          // The side column's card in landscape, the bottom strip upright.
          final style = editor.last.$2;
          expect(style.layout, size.width > size.height ? AdLayout.compact : AdLayout.strip);
          expect(find.byType(TabletAdCard), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(platform));
    }
  }

  for (final size in [landscape, portrait]) {
    testWidgets('T5.1 / T5.2: one Timing & Look ad, in the same place on both tabs at $size', (tester) async {
      final app = harness();
      await app.pump(tester, size: size);
      await tap(tester, 'The Long Way Down');
      await tap(tester, 'Timing');
      expect(requests(app, AdPlacement.timingLook), isNotEmpty);
      final timing = tester.getRect(find.byType(EdgeAdSlot));

      await tap(tester, 'Look');
      expect(find.byType(EdgeAdSlot), findsOneWidget);
      expect(tester.getRect(find.byType(EdgeAdSlot)), timing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Pro sees no editor or Timing & Look ad', (tester) async {
    final app = harness(plan: const Entitlement.pro(period: BillingPeriod.yearly));
    await app.pump(tester, size: landscape);
    await tap(tester, 'The Long Way Down');
    await tap(tester, 'Timing');
    final placements = app.ads.requested.map((r) => r.$1);
    expect(placements, isNot(contains(AdPlacement.editor)));
    expect(placements, isNot(contains(AdPlacement.timingLook)));
    expect(find.byType(TabletAdCard), findsNothing);
  });

  testWidgets('the editor ad hides while the keyboard is up', (tester) async {
    final app = harness();
    await app.pump(tester, size: portrait);
    await tap(tester, 'The Long Way Down');
    expect(find.byType(TabletAdCard), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.byType(TabletAdCard), findsNothing);
    // Kept in the tree behind the keyboard, so the loaded ad comes back.
    expect(
      find.descendant(
        of: find.byType(EdgeAdSlot, skipOffstage: false),
        matching: find.byType(TabletAdCard, skipOffstage: false),
        skipOffstage: false,
      ),
      findsOneWidget,
    );

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.byType(TabletAdCard), findsOneWidget);
  });
}
