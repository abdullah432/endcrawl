import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/bootstrap.dart';
import 'package:lastreel/core/theme/app_theme.dart';
import 'package:lastreel/core/widgets/ec_ad_slot.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/access/controllers/web_access.dart';
import 'package:lastreel/features/ads/ads_providers.dart';
import 'package:lastreel/features/ads/data/ad_service.dart';
import 'package:lastreel/features/settings/screens/settings_screen.dart';
import 'package:lastreel/features/settings/widgets/settings_tablet_ad.dart';

import '../../support/app_harness.dart';
import '../../support/fake_export.dart';

class _SettingsAds extends FakeAdService {
  final placements = <AdPlacement>[];
  bool hasInventory = true;

  @override
  Widget nativeAd(
    AdPlacement placement, {
    required Widget Function(Widget creative) framed,
  }) {
    placements.add(placement);
    return hasInventory
        ? super.nativeAd(placement, framed: framed)
        : const SizedBox.shrink();
  }
}

const tablet = Size(1194, 834);

void main() {
  final mobile = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
  });

  for (final size in [
    tablet,
    const Size(834, 1194),
    const Size(1366, 1024),
    const Size(500, 834),
  ]) {
    testWidgets('native tablet Settings shows the placement at $size', (
      tester,
    ) async {
      final ads = _SettingsAds();
      final app = AppHarness()..ads = ads;
      await app.pump(tester, size: size);
      if (size.width == 500) {
        // The window is narrow, but the iPad display has not changed.
        tester.view.display.size = tablet;
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Account').first);
      } else {
        await tester.tap(find.text('Settings').first);
      }
      await tester.pumpAndSettle();
      expect(ads.placements, contains(AdPlacement.settings));
      expect(
        find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(EcAdSlot),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      if (size == tablet) {
        await tester.tap(find.text('Support'));
        await tester.pumpAndSettle();
        expect(find.text('Help centre'), findsOneWidget);
        expect(find.byType(SettingsTabletAd), findsOneWidget);
        app.plan.entitlement = const Entitlement.pro();
        await tester.pumpAndSettle();
        expect(find.byType(EcAdSlot), findsNothing);
      }
    }, variant: mobile);
  }

  Future<_SettingsAds> mount(
    WidgetTester tester, {
    Size displaySize = tablet,
    bool web = false,
    bool inventory = true,
  }) async {
    tester.view.display.size = displaySize;
    tester.view.display.devicePixelRatio = 1;
    addTearDown(tester.view.display.reset);
    final ads = _SettingsAds()..hasInventory = inventory;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entitlementProvider.overrideWith(
            (ref) => Stream.value(const Entitlement.free()),
          ),
          adServiceProvider.overrideWithValue(ads),
          runningOnWebProvider.overrideWithValue(web),
        ],
        child: MaterialApp(
          theme: buildLastReelTheme(),
          home: const Scaffold(body: SettingsTabletAd()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ads;
  }

  testWidgets('phone Settings never requests the tablet unit', (tester) async {
    final ads = await mount(tester, displaySize: AppHarness.phone);
    expect(ads.placements, isEmpty);
    expect(find.byType(EcAdSlot), findsNothing);
  }, variant: mobile);

  testWidgets('web never requests the tablet unit, even on an iPad display', (
    tester,
  ) async {
    final ads = await mount(tester, web: true);
    expect(ads.placements, isEmpty);
    expect(find.byType(EcAdSlot), findsNothing);
  }, variant: mobile);

  testWidgets('no fill leaves no sponsored frame or gap', (tester) async {
    final ads = await mount(tester, inventory: false);
    expect(ads.placements, [AdPlacement.settings]);
    expect(find.byType(EcAdSlot), findsNothing);
    // Scaffold gives its child loose constraints; an absent ad is empty.
    expect(tester.getSize(find.byType(SettingsTabletAd)).height, 0);
  }, variant: mobile);
}
