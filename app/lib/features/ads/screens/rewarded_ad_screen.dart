import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../ads_providers.dart';
import '../data/ad_service.dart';

/// 6.1a — one rewarded ad for one Pro render.
///
/// Opened only from the "Watch ad · render once" button, never on its own.
/// A black stage with what the ad is for ("Unlocking ProRes 422 HQ · This
/// render only · starts when the ad ends") while the ad loads, then the ad
/// network's own full-screen player, whose countdown and close button (it
/// appears once the reward is earned) are the network's. Pops with how the
/// ad ended; the caller starts the render on [RewardOutcome.earned].
class RewardedAdScreen extends ConsumerStatefulWidget {
  /// What the ad unlocks — "ProRes 422 HQ", "4K UHD".
  final String unlocking;

  const RewardedAdScreen({super.key, required this.unlocking});

  static Future<RewardOutcome> show(BuildContext context, {required String unlocking}) async {
    final outcome = await Navigator.of(context, rootNavigator: true).push<RewardOutcome>(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: EcMotion.slow,
        pageBuilder: (_, _, _) => RewardedAdScreen(unlocking: unlocking),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
    return outcome ?? RewardOutcome.closedEarly;
  }

  @override
  ConsumerState<RewardedAdScreen> createState() => _RewardedAdScreenState();
}

class _RewardedAdScreenState extends ConsumerState<RewardedAdScreen> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  Future<void> _play() async {
    final outcome = await ref.read(adServiceProvider).showRewarded();
    _finish(outcome);
  }

  void _finish(RewardOutcome outcome) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(RewardOutcome.closedEarly);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AD · LOADING',
                        style: t.mono.copyWith(fontSize: 10, letterSpacing: 1.4, color: Colors.white.withValues(alpha: .85)),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _finish(RewardOutcome.closedEarly),
                      style: TextButton.styleFrom(foregroundColor: Colors.white.withValues(alpha: .8)),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 34),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(EcRadius.card),
                  border: Border.all(color: Colors.white.withValues(alpha: .22)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(gradient: p.primary, shape: BoxShape.circle),
                      child: Text('PRO', style: t.pill.copyWith(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Unlocking ${widget.unlocking}',
                              style: t.titleS.copyWith(fontSize: 13.5, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('This render only · starts when the ad ends',
                              style: t.caption.copyWith(fontSize: 11.5, color: Colors.white.withValues(alpha: .8))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
