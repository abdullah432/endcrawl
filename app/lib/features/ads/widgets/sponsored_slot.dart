import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/widgets/ec_ad_slot.dart';
import '../../plan/screens/pro_sheet.dart';
import '../../plan/controllers/release_policy.dart';
import '../ads_providers.dart';
import '../data/ad_service.dart';
import 'tablet_ad.dart';
import '../../home/tablet_layout.dart';

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
    final showsAds = ref.watch(entitlementProvider).value?.showsAds ?? false;
    if (!showsAds) return const SizedBox.shrink();
    final freeLaunch = ref.watch(iosFreeLaunchProvider);
    // The tablet reports its slots (§7); the phone's stay as they were.
    final tablet = context.isTablet;
    final analytics = ref.read(analyticsProvider);
    void log(String event) => analytics.logEvent(event, {'slot': TabletAdSlot.slotName(placement)});
    return ref
        .read(adServiceProvider)
        .nativeAd(
          placement,
          style: tablet
              ? AdSlotStyle(
                  onShown: () => log('ad_slot_shown'),
                  onEmpty: () => log('ad_slot_empty'),
                  onTapped: () => log('ad_tapped'),
                )
              : const AdSlotStyle(),
          framed: (creative) => Padding(
            padding: EdgeInsets.only(top: gap),
            child: EcAdSlot(
              label: label,
              hideLabel: hideLabel,
              onHideAds: freeLaunch
                  ? null
                  : () {
                      if (tablet) log('remove_ads_tapped');
                      ProSheet.show(context);
                    },
              creative: creative,
            ),
          ),
        );
  }
}

/// A tablet ad slot on the free plan (§5): the library's foot strip
/// (`library_foot`) or the card under the Settings list (`settings_list`).
/// Nothing on Pro. Keeps its height while the ad loads and closes up if
/// none arrives, so the screen never jumps.
class TabletAdSlot extends ConsumerWidget {
  final AdPlacement placement;
  final AdLayout layout;
  final bool portrait;

  /// Space above the slot, kept only while the slot is.
  final double gap;

  const TabletAdSlot(this.placement, {super.key, required this.layout, this.portrait = false, this.gap = 0});

  /// The slot's analytics name.
  static String slotName(AdPlacement placement) => switch (placement) {
    AdPlacement.library => 'library_foot',
    AdPlacement.exportSettings => 'export_settings_foot',
    AdPlacement.rendering => 'render_wait',
    AdPlacement.exportComplete => 'export_ready',
    AdPlacement.editor => 'editor_foot',
    AdPlacement.timingLook => 'timing_look_foot',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showsAds = ref.watch(entitlementProvider).value?.showsAds ?? false;
    if (!showsAds) return const SizedBox.shrink();
    final freeLaunch = ref.watch(iosFreeLaunchProvider);
    final analytics = ref.read(analyticsProvider);
    void log(String event) => analytics.logEvent(event, {'slot': slotName(placement)});
    final height = TabletAdMetrics.height(layout, portrait: portrait, text: MediaQuery.textScalerOf(context));
    return ref
        .read(adServiceProvider)
        .nativeAd(
          placement,
          style: AdSlotStyle(
            layout: layout,
            portrait: portrait,
            reserve: height + gap,
            onShown: () => log('ad_slot_shown'),
            onEmpty: () => log('ad_slot_empty'),
            onTapped: () => log('ad_tapped'),
          ),
          framed: (creative) => Padding(
            padding: EdgeInsets.only(top: gap),
            child: TabletAdCard(
              layout: layout,
              portrait: portrait,
              height: height,
              creative: creative,
              onRemoveAds: freeLaunch
                  ? null
                  : () {
                      log('remove_ads_tapped');
                      ProSheet.show(context);
                    },
            ),
          ),
        );
  }
}
