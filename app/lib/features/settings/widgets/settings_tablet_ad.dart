import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/adaptive_layout.dart';
import '../../access/controllers/web_access.dart';
import '../../ads/data/ad_service.dart';
import '../../ads/widgets/sponsored_slot.dart';

/// The Settings placement is for native tablets, including an iPad using
/// a narrow split-view window. Phones and web never request this placement.
class SettingsTabletAd extends ConsumerWidget {
  const SettingsTabletAd({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(runningOnWebProvider) ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android) ||
        isNativePhone(context)) {
      return const SizedBox.shrink();
    }
    return const SponsoredSlot(AdPlacement.settings, gap: 22);
  }
}
