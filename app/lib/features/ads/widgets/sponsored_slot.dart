import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/widgets/ec_ad_slot.dart';
import '../../plan/screens/pro_sheet.dart';
import '../ads_providers.dart';
import '../data/ad_service.dart';

/// A native ad slot on the free plan: nothing at all on Pro, otherwise
/// "Sponsored" with a way out to Pro above the placement's ad.
class SponsoredSlot extends ConsumerWidget {
  final AdPlacement placement;
  final String label;
  final String hideLabel;

  /// Space above the slot, shown only when the slot is.
  final double gap;

  const SponsoredSlot(this.placement, {super.key, this.label = 'Sponsored', this.hideLabel = 'Hide ads', this.gap = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showsAds = ref.watch(entitlementProvider).value?.showsAds ?? true;
    if (!showsAds) return const SizedBox.shrink();
    return ref.read(adServiceProvider).nativeAd(
          placement,
          framed: (creative) => Padding(
            padding: EdgeInsets.only(top: gap),
            child: EcAdSlot(
              label: label,
              hideLabel: hideLabel,
              onHideAds: () => ProSheet.show(context),
              creative: creative,
            ),
          ),
        );
  }
}
