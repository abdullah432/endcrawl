import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/ad_config.dart';
import '../../export/controllers/export_controller.dart';
import '../ads_providers.dart';

/// The app-open ad, shown only when the app comes back from the
/// background — never on a cold start, never after a short trip away
/// (the share sheet, a permission prompt), never on Pro, and never over a
/// render in progress. How often it may show is AdMob's per-unit
/// frequency cap, set in the console.
class ResumeAds extends ConsumerStatefulWidget {
  final Widget child;

  const ResumeAds({super.key, required this.child});

  @override
  ConsumerState<ResumeAds> createState() => _ResumeAdsState();
}

class _ResumeAdsState extends ConsumerState<ResumeAds> {
  late final AppLifecycleListener _lifecycle;
  DateTime? _hiddenAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onHide() => _hiddenAt = ref.read(clockProvider)();

  void _onShow() {
    final hiddenAt = _hiddenAt;
    _hiddenAt = null;
    if (hiddenAt == null) return;
    if (ref.read(clockProvider)().difference(hiddenAt) < AppOpenPolicy.minBackground) return;
    if (!(ref.read(entitlementProvider).value?.showsAds ?? false)) return;
    if (ref.read(exportControllerProvider).rendering) return;
    ref.read(adServiceProvider).showAppOpen();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
