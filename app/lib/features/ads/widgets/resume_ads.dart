import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../ads_providers.dart';

/// The app-open ad, shown whenever the app comes back from the background
/// — never on a cold start and never on Pro. One is loaded as soon as the
/// plan reads as free, so the first return already has it. A render in progress keeps
/// going behind it. How often it may show is AdMob's per-unit frequency
/// cap, set in the console.
class ResumeAds extends ConsumerStatefulWidget {
  final Widget child;

  const ResumeAds({super.key, required this.child});

  @override
  ConsumerState<ResumeAds> createState() => _ResumeAdsState();
}

class _ResumeAdsState extends ConsumerState<ResumeAds> {
  late final AppLifecycleListener _lifecycle;
  bool _wasHidden = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    ref.listenManual(entitlementProvider, (previous, next) {
      final free = next.value?.showsAds ?? false;
      if (free && !(previous?.value?.showsAds ?? false)) ref.read(adServiceProvider).preloadAppOpen();
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onHide() => _wasHidden = true;

  void _onShow() {
    if (!_wasHidden) return;
    _wasHidden = false;
    if (!(ref.read(entitlementProvider).value?.showsAds ?? false)) return;
    ref.read(adServiceProvider).showAppOpen();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
