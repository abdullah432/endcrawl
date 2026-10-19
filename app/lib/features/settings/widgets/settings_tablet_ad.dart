import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../access/controllers/web_access.dart';
import '../../ads/data/ad_service.dart';
import '../../ads/widgets/sponsored_slot.dart';
import '../../home/tablet_layout.dart';
import '../../home/widgets/app_side_nav.dart';

/// The Settings placement, below the Settings content, for Android tablets
/// only — including one in a narrow split-view window. Phones and web never
/// request it, and it is hidden on iPad for now.
///
/// In the tablet's Settings tab it is drawn as the tablet ad strip, and
/// only while that tab shows, so the hidden tab requests no ad. Elsewhere
/// (a split-view window, a desktop-width tablet) it is the phone's row.
class SettingsTabletAd extends ConsumerWidget {
  const SettingsTabletAd({super.key});

  static const gap = 22.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(runningOnWebProvider) ||
        defaultTargetPlatform != TargetPlatform.android ||
        isNativePhone(context)) {
      return const SizedBox.shrink();
    }
    final tablet = context.tabletLayout;
    if (tablet == null) return const SponsoredSlot(AdPlacement.settings, gap: gap);
    if (ref.watch(homeTabProvider) != HomeDestination.settings) return const SizedBox.shrink();
    return TabletAdSlot(
      AdPlacement.settings,
      layout: AdLayout.strip,
      portrait: tablet == TabletLayout.portrait,
      gap: gap,
    );
  }
}
