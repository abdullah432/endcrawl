import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/bootstrap.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/ads/ads_providers.dart';
import 'package:lastreel/features/ads/data/ad_service.dart';
import 'package:lastreel/features/ads/widgets/sponsored_slot.dart';

import '../../support/fake_export.dart';

class _CountingAds extends FakeAdService {
  int nativeRequests = 0;

  @override
  Widget nativeAd(
    AdPlacement placement, {
    required Widget Function(Widget creative) framed,
  }) {
    nativeRequests++;
    return const Text('Native inventory');
  }
}

void main() {
  testWidgets(
    'waits for the plan, then requests immediately on Free and disappears on Pro',
    (tester) async {
      final plan = StreamController<Entitlement>();
      final ads = _CountingAds();
      final container = ProviderContainer(
        overrides: [
          entitlementProvider.overrideWith((ref) => plan.stream),
          adServiceProvider.overrideWithValue(ads),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await plan.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: SponsoredSlot(AdPlacement.library)),
          ),
        ),
      );
      expect(ads.nativeRequests, 0);
      plan.add(const Entitlement.free());
      await tester.pumpAndSettle();
      expect(ads.nativeRequests, 1);
      expect(find.text('Native inventory'), findsOneWidget);
      plan.add(const Entitlement.pro());
      await tester.pumpAndSettle();
      expect(ads.nativeRequests, 1);
      expect(find.text('Native inventory'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
