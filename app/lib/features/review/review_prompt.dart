import 'dart:async';

import '../../core/config/app_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap.dart';
import '../tracking/tracking_prompt.dart';
import '../../core/root_navigator.dart';
import '../../core/theme/theme_context.dart';
import '../../core/theme/ec_type.dart';
import '../../core/widgets/ec_button.dart';
import '../../core/widgets/ec_chip.dart';
import '../../core/widgets/ec_fields.dart';
import '../../core/widgets/ec_headline.dart';
import '../../core/widgets/ec_scaffold.dart';
import '../../core/widgets/ec_sheet.dart';
import '../../core/widgets/ec_toast.dart';
import '../ads/ads_providers.dart';
import '../export/controllers/export_controller.dart';
import '../export/models/export_models.dart';
import '../settings/controllers/settings_controller.dart';
import 'data/feedback_repository.dart';
import 'review_prompt_store.dart';

/// Overridden in `main` with the SharedPreferences-backed store, and in
/// tests with an in-memory one.
final reviewPromptStoreProvider = Provider<ReviewPromptStore>((ref) {
  throw StateError(
    'reviewPromptStoreProvider was not overridden — see bootstrap().',
  );
});

/// Whether the rating prompt came up in this run of the app. The desk
/// invite (1.8) stays out of the same session, so nobody gets two asks at once.
final reviewPromptShownThisSessionProvider =
    NotifierProvider<ShownThisSession, bool>(ShownThisSession.new);

class ShownThisSession extends Notifier<bool> {
  @override
  bool build() => false;

  void mark() => state = true;

  void reset() => state = false;
}

/// Where the rating ask is on screen, when it's inside the Rendering sheet
/// (6.2a–c) rather than a sheet of its own.
enum InlineRatePhase {
  off,

  /// 6.2a — the two paths: the store, or private feedback.
  asking,

  /// 6.2c — the store's review is opening.
  opening,

  /// 6.2b — private feedback, in place of the render's own view.
  feedback,
}

class InlineRate {
  final InlineRatePhase phase;
  const InlineRate(this.phase);
}

class InlineRateController extends Notifier<InlineRate> {
  @override
  InlineRate build() => const InlineRate(InlineRatePhase.off);

  void ask() => state = const InlineRate(InlineRatePhase.asking);
  void openStore() => state = const InlineRate(InlineRatePhase.opening);
  void askFeedback() => state = const InlineRate(InlineRatePhase.feedback);
  void close() => state = const InlineRate(InlineRatePhase.off);
}

final inlineRateProvider = NotifierProvider<InlineRateController, InlineRate>(
  InlineRateController.new,
);

/// What the person picked on 6.2a or 6.2b.
enum RateChoice { store, feedback }

/// The rating ask, while a render runs.
///
/// 6.2a — it takes the place of the ad in the Rendering sheet, so it never
/// covers the progress; if the person went back to work, it comes up as a
/// sheet of its own instead. It offers two paths side by side and asks for
/// no stars first, so a rating never decides who reaches the store:
/// 6.2c — the store's own review (the same as Settings → Rate LastReel);
/// 6.2b — private feedback to the team, which never goes to the store and
/// keeps the store one tap away. Once someone has gone to the store it
/// never asks again; "Not now" or feedback can be asked again 30 days
/// later, up to [maxAsks] times in all (see [due]).
abstract final class ReviewPrompt {
  /// Between asks: "Not now" or private feedback waits this long.
  static const quiet = Duration(days: 30);

  /// Asked on its own at most this often per device, however it went.
  static const maxAsks = 3;

  /// The store the review goes to: Google Play on Android, else the App Store.
  static String get storeName =>
      defaultTargetPlatform == TargetPlatform.android ? 'Google Play' : 'the App Store';

  /// "Rate on the App Store" / "Rate on Google Play".
  static String get rateLabel => 'Rate on $storeName';

  /// Whether it may ask now: never again once someone went to the store
  /// (asking again only annoys); otherwise 30 days after the last ask, and
  /// no more than [maxAsks] times in all.
  static bool due(ReviewPromptStore store, DateTime now) {
    if (store.lastAnswer == ReviewAnswer.rated) return false;
    if (store.timesAsked >= maxAsks) return false;
    final last = store.lastAsked;
    return last == null || !now.isBefore(last.add(quiet));
  }

  static Future<void> maybeShow(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final store = container.read(reviewPromptStoreProvider);
    final now = container.read(clockProvider)();
    // The web has no store to rate in; and one ask per session — not in the
    // one the tracking pre-prompt had.
    if (!AppPlatform.isMobile || !due(store, now) || container.read(trackingPromptThisSessionProvider)) return;
    await store.markAsked(now);
    container.read(reviewPromptShownThisSessionProvider.notifier).mark();
    container.read(analyticsProvider).logEvent('review_prompt_shown');

    if (RateSlot.open > 0) {
      container.read(inlineRateProvider.notifier).ask();
      return;
    }
    if (!context.mounted) return;
    await _askInSheet(context, container);
  }

  /// Settings → Rate LastReel: the same two paths, asked because the person
  /// chose to — so it ignores whether the prompt already came up.
  static Future<void> askNow(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(analyticsProvider).logEvent('review_prompt_shown', {
      'source': 'settings',
    });
    await _askInSheet(context, container, whileRendering: false);
  }

  static Future<void> _askInSheet(
    BuildContext context,
    ProviderContainer container, {
    bool whileRendering = true,
  }) async {
    final choice = await showEcSheet<RateChoice>(
      context,
      builder: (_) => ReviewPromptSheet(whileRendering: whileRendering),
    );
    switch (choice) {
      case null:
        return later(container);
      case RateChoice.store:
        return toStore(container);
      case RateChoice.feedback:
        container.read(analyticsProvider).logEvent('review_prompt_feedback');
        if (!context.mounted) return;
        final result = await showEcSheet<Object>(
          context,
          builder: (_) => const ReviewFeedbackSheet(),
        );
        if (result == RateChoice.store) return toStore(container);
        sendToTeam(container, result is RatingFeedback ? result : null);
    }
  }

  /// "Not now", or closed without picking.
  static Future<void> later(ProviderContainer container) async {
    await container.read(reviewPromptStoreProvider).recordAnswer(ReviewAnswer.later);
    container.read(analyticsProvider).logEvent('review_prompt_later');
  }

  /// The store's own review card — the same as Settings → Rate LastReel.
  static Future<void> toStore(ProviderContainer container) async {
    container.read(analyticsProvider).logEvent('review_prompt_rate');
    await container.read(reviewPromptStoreProvider).recordAnswer(ReviewAnswer.rated);
    await container.read(settingsControllerProvider).rate();
  }

  /// Private feedback: the report goes to the team, never the store. Closed
  /// without sending, it counts as "Not now".
  static void sendToTeam(ProviderContainer container, RatingFeedback? report) {
    if (report == null) {
      later(container);
      return;
    }
    container.read(reviewPromptStoreProvider).recordAnswer(ReviewAnswer.low);
    container.read(analyticsProvider).logEvent('review_prompt_feedback_sent', {
      'rating': report.rating,
      'topics': report.topics.length,
    });
    container.read(feedbackRepositoryProvider).submit(report);
    // Raised from the root navigator's own overlay context, which can't
    // look itself up; show the thanks on that overlay directly.
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay != null && overlay.mounted) {
      showEcToastOn(overlay, 'Thanks. The team reads every one.');
    }
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
  ConsumerState<ReviewPromptTrigger> createState() =>
      _ReviewPromptTriggerState();
}

class _ReviewPromptTriggerState extends ConsumerState<ReviewPromptTrigger> {
  Timer? _timer;

  bool get _rendering => ref.read(exportControllerProvider).rendering;

  void _schedule(Duration after, {bool finished = false}) {
    _timer?.cancel();
    _timer = Timer(after, () => _fire(finished: finished));
  }

  void _fire({bool finished = false}) {
    if (!mounted ||
        !ReviewPrompt.due(
          ref.read(reviewPromptStoreProvider),
          ref.read(clockProvider)(),
        )) {
      return;
    }
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
        if (pending &&
            ref.read(exportControllerProvider).run?.phase == ExportPhase.done) {
          _fire(finished: true);
        }
      }
    });
    return widget.child;
  }
}

/// 6.2a as a sheet of its own — for when the Rendering sheet isn't open.
/// Pops the [RateChoice], or nothing for "Not now".
class ReviewPromptSheet extends StatelessWidget {
  /// "While you wait" sits above the question only during a render.
  final bool whileRendering;
  const ReviewPromptSheet({super.key, this.whileRendering = true});

  @override
  Widget build(BuildContext context) {
    return EcSheet(
      child: RateQuestion(
        onStore: () => Navigator.of(context).pop(RateChoice.store),
        onFeedback: () => Navigator.of(context).pop(RateChoice.feedback),
        onLater: () => Navigator.of(context).pop(),
        whileRendering: whileRendering,
      ),
    );
  }
}

/// 6.2a — "How's LastReel working for you?" and two equal paths. No stars
/// first: the store is open to everyone, whatever they think.
class RateQuestion extends StatelessWidget {
  final VoidCallback onStore;
  final VoidCallback onFeedback;
  final VoidCallback onLater;
  final bool whileRendering;

  const RateQuestion({
    super.key,
    required this.onStore,
    required this.onFeedback,
    required this.onLater,
    this.whileRendering = true,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (whileRendering) ...[
          Text(
            caps('While you wait'),
            textAlign: TextAlign.center,
            style: t.eyebrow.copyWith(fontSize: 11, letterSpacing: 11 * .14),
          ),
          const SizedBox(height: 8),
        ],
        EcHeadline(
          'How’s LastReel ',
          emphasis: 'working for you?',
          style: t.displayM.copyWith(fontSize: 28, height: 1.05),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Rate it on ${ReviewPrompt.storeName}, or tell the team privately what to fix.',
          textAlign: TextAlign.center,
          style: t.bodyS.copyWith(fontSize: 13, color: p.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        EcButton(label: ReviewPrompt.rateLabel, height: 50, onPressed: onStore),
        const SizedBox(height: 8),
        EcButton(
          label: 'Send private feedback',
          variant: EcButtonVariant.secondary,
          height: 50,
          onPressed: onFeedback,
        ),
        const SizedBox(height: 4),
        EcButton(
          label: 'Not now',
          variant: EcButtonVariant.plain,
          size: EcButtonSize.medium,
          expand: true,
          onPressed: onLater,
        ),
      ],
    );
  }
}

/// 6.2c, inside the Rendering sheet — the store's own review is opening.
class OpeningStore extends StatelessWidget {
  const OpeningStore({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Semantics(
        liveRegion: true,
        child: EcHeadline(
          'Opening the ',
          emphasis: '${ReviewPrompt.storeName} review…',
          style: t.displayM.copyWith(fontSize: 26),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// The ad's place in the Rendering and Ready views — the rating card
/// while it's being asked (6.2a/c), the ad otherwise. Counts itself while
/// on screen, so the prompt knows whether it can appear here.
class RateSlot extends ConsumerStatefulWidget {
  final Widget ad;
  const RateSlot({super.key, required this.ad});

  /// How many slots are on screen right now.
  static int open = 0;

  @override
  ConsumerState<RateSlot> createState() => _RateSlotState();
}

class _RateSlotState extends ConsumerState<RateSlot> {
  @override
  void initState() {
    super.initState();
    RateSlot.open++;
  }

  @override
  void dispose() {
    RateSlot.open--;
    super.dispose();
  }

  Future<void> _store() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final controller = ref.read(inlineRateProvider.notifier);
    controller.openStore();
    await ReviewPrompt.toStore(container);
    controller.close();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final phase = ref.watch(inlineRateProvider.select((s) => s.phase));
    if (phase != InlineRatePhase.asking && phase != InlineRatePhase.opening) {
      return widget.ad;
    }
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.accentLine, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x800C6EC8),
            offset: Offset(0, 16),
            blurRadius: 30,
            spreadRadius: -20,
          ),
        ],
      ),
      child: phase == InlineRatePhase.opening
          ? const OpeningStore()
          : RateQuestion(
              onStore: _store,
              onFeedback: () {
                ref.read(analyticsProvider).logEvent('review_prompt_feedback');
                ref.read(inlineRateProvider.notifier).askFeedback();
              },
              onLater: () {
                ReviewPrompt.later(ProviderScope.containerOf(context, listen: false));
                ref.read(inlineRateProvider.notifier).close();
              },
            ),
    );
  }
}

/// Five tappable stars; tapping the third makes it three, and tapping the
/// current one again clears it (the rating is optional). A slider to
/// assistive tech, so it can be adjusted without seeing the stars.
class StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const StarRating({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      slider: true,
      label: 'Your rating, optional',
      value: value == 0 ? 'No stars' : '$value of 5 stars',
      increasedValue: value < 5 ? '${value + 1} of 5 stars' : null,
      decreasedValue: value > 0 ? (value == 1 ? 'No stars' : '${value - 1} of 5 stars') : null,
      onIncrease: value < 5 ? () => onChanged(value + 1) : null,
      onDecrease: value > 0 ? () => onChanged(value - 1) : null,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                key: ValueKey('star-$i'),
                iconSize: 28,
                constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                padding: EdgeInsets.zero,
                onPressed: () => onChanged(i == value ? 0 : i),
                // Unfilled stars use muted ink, which keeps 3:1 against
                // the sheet; the faint tone did not.
                icon: i <= value
                    ? Icon(Icons.star_rounded, color: p.accentSolid)
                    : Icon(Icons.star_outline_rounded, color: p.muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// 6.2b as a sheet of its own. Pops the [RatingFeedback] that was sent,
/// [RateChoice.store] for "Rate on … instead", or nothing when closed.
class ReviewFeedbackSheet extends StatelessWidget {
  const ReviewFeedbackSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return EcSheet(
      child: ReviewFeedbackForm(
        onSend: (report) => Navigator.of(context).pop(report),
        onStore: () => Navigator.of(context).pop(RateChoice.store),
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// 6.2b — private feedback, open to everyone. The rating is optional and
/// starts empty; topics and a note go to the team, never the store, and
/// the store stays one tap away at the bottom.
class ReviewFeedbackForm extends StatefulWidget {
  final ValueChanged<RatingFeedback> onSend;
  final VoidCallback onStore;
  final VoidCallback onClose;

  const ReviewFeedbackForm({
    super.key,
    required this.onSend,
    required this.onStore,
    required this.onClose,
  });

  @override
  State<ReviewFeedbackForm> createState() => _ReviewFeedbackFormState();
}

class _ReviewFeedbackFormState extends State<ReviewFeedbackForm> {
  /// 0 = not given.
  int _rating = 0;
  final _topics = <FeedbackTopic>{};
  final _message = TextEditingController();

  @override
  void initState() {
    super.initState();
    _message.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _empty => _rating == 0 && _topics.isEmpty && _message.text.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final label = t.eyebrow.copyWith(fontSize: 11, letterSpacing: 11 * .14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: EcHeadline('Private ', emphasis: 'feedback', style: t.displayM),
              ),
            ),
            SizedBox.square(
              dimension: 44,
              child: Center(
                child: EcCircleButton.tint(
                  icon: Icons.close_rounded,
                  size: 34,
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Goes straight to the people who build LastReel. Nothing here is posted publicly.',
            style: t.bodyS.copyWith(color: p.muted, height: 1.45),
          ),
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(caps('Your rating · optional'), style: label),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: StarRating(value: _rating, onChanged: (v) => setState(() => _rating = v)),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(caps('Topics · optional'), style: label),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final topic in FeedbackTopic.values)
              EcChip(
                label: _topics.contains(topic) ? '✓ ${topic.label}' : topic.label,
                selected: _topics.contains(topic),
                height: 40,
                onTap: () => setState(
                  () => _topics.contains(topic) ? _topics.remove(topic) : _topics.add(topic),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        EcTextArea(
          controller: _message,
          label: 'Tell us more · optional',
          hint: 'What happened, and what did you expect?',
          minLines: 3,
          maxLines: 6,
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Sent privately with your app version. No project content is included.',
            style: t.caption.copyWith(fontSize: 12),
          ),
        ),
        const SizedBox(height: 18),
        EcButton(
          label: 'Send to the team',
          onPressed: _empty
              ? null
              : () => widget.onSend(
                    RatingFeedback(rating: _rating, topics: {..._topics}, message: _message.text),
                  ),
        ),
        const SizedBox(height: 4),
        EcButton(
          label: '${ReviewPrompt.rateLabel} instead',
          variant: EcButtonVariant.plain,
          size: EcButtonSize.medium,
          expand: true,
          onPressed: widget.onStore,
        ),
      ],
    );
  }
}
