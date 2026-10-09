import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap.dart';
import '../../core/root_navigator.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/ec_button.dart';
import '../../core/widgets/ec_headline.dart';
import '../../core/widgets/ec_sheet.dart';
import '../ads/ads_providers.dart';
import '../export/controllers/export_controller.dart';
import '../export/models/export_models.dart';
import '../settings/controllers/settings_controller.dart';
import 'review_prompt_store.dart';

/// Overridden in `main` with the SharedPreferences-backed store, and in
/// tests with an in-memory one.
final reviewPromptStoreProvider = Provider<ReviewPromptStore>((ref) {
  throw StateError('reviewPromptStoreProvider was not overridden — see bootstrap().');
});

/// The one-time "Enjoying LastReel?" ask, while the first render runs.
///
/// "Rate LastReel" hands over to the system rating dialog (the same as
/// Settings → Rate LastReel); whatever they pick, it is never asked again
/// on this device.
abstract final class ReviewPrompt {
  static Future<void> maybeShow(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final store = container.read(reviewPromptStoreProvider);
    // The web has no store to rate in.
    if (kIsWeb || store.asked) return;
    await store.markAsked();
    final analytics = container.read(analyticsProvider)..logEvent('review_prompt_shown');
    if (!context.mounted) return;

    final rate = await showEcSheet<bool>(context, builder: (_) => const ReviewPromptSheet());
    analytics.logEvent(rate == true ? 'review_prompt_rate' : 'review_prompt_later');
    if (rate == true) await container.read(settingsControllerProvider).rate();
  }
}

/// Raises [ReviewPrompt] a few seconds into a render — on top of the
/// Rendering sheet, or over whatever screen the person went back to with
/// "Keep working". A render that finishes sooner asks as it finishes.
/// Never over a full-screen ad: it waits for the ad to close. A render that
/// is cancelled or fails first doesn't ask, so the next one can. Sits above every route, in `MaterialApp.builder`.
class ReviewPromptTrigger extends ConsumerStatefulWidget {
  final Widget child;
  const ReviewPromptTrigger({super.key, required this.child});

  /// Long enough to see the render has started before anything covers it.
  static const delay = Duration(seconds: 3);

  @override
  ConsumerState<ReviewPromptTrigger> createState() => _ReviewPromptTriggerState();
}

class _ReviewPromptTriggerState extends ConsumerState<ReviewPromptTrigger> {
  Timer? _timer;

  bool get _rendering => ref.read(exportControllerProvider).rendering;

  void _schedule(Duration after, {bool finished = false}) {
    _timer?.cancel();
    _timer = Timer(after, () => _fire(finished: finished));
  }

  void _fire({bool finished = false}) {
    if (!mounted || ref.read(reviewPromptStoreProvider).asked) return;
    if (!finished && !_rendering) return;
    if (ref.read(adServiceProvider).showingFullScreen) {
      return _schedule(const Duration(seconds: 2), finished: finished);
    }
    final routeContext = rootNavigatorKey.currentState?.overlay?.context;
    if (routeContext != null) ReviewPrompt.maybeShow(routeContext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(exportControllerProvider.select((s) => s.rendering), (was, now) {
      if (now && was != true) {
        _schedule(ReviewPromptTrigger.delay);
      } else if (!now) {
        final pending = _timer?.isActive ?? false;
        _timer?.cancel();
        if (pending && ref.read(exportControllerProvider).run?.phase == ExportPhase.done) _fire(finished: true);
      }
    });
    return widget.child;
  }
}

class ReviewPromptSheet extends StatelessWidget {
  const ReviewPromptSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return EcSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => p.primary.createShader(bounds),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [for (var i = 0; i < 5; i++) const Icon(Icons.star_rounded, size: 34)],
              ),
            ),
          ),
          const SizedBox(height: 16),
          EcHeadline(
            'Enjoying ',
            emphasis: 'LastReel?',
            style: t.displayM.copyWith(fontSize: 34),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'While your credits render: if LastReel has been useful, a quick rating helps other editors find it.',
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: p.muted),
            ),
          ),
          const SizedBox(height: 24),
          EcButton(label: 'Rate LastReel', onPressed: () => Navigator.of(context).pop(true)),
          const SizedBox(height: 6),
          EcButton(
            label: 'Not now',
            variant: EcButtonVariant.plain,
            expand: true,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
