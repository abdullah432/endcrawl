import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap.dart';
import '../../core/root_navigator.dart';
import '../../core/theme/theme_context.dart';
import '../../core/theme/ec_type.dart';
import '../../core/widgets/ec_button.dart';
import '../../core/widgets/ec_chip.dart';
import '../../core/widgets/ec_fields.dart';
import '../../core/widgets/ec_headline.dart';
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
  throw StateError('reviewPromptStoreProvider was not overridden — see bootstrap().');
});

/// Whether the rating prompt came up in this run of the app. The desk
/// invite (1.8) stays out of the same session, so nobody gets two asks at once.
final reviewPromptShownThisSessionProvider = NotifierProvider<ShownThisSession, bool>(ShownThisSession.new);

class ShownThisSession extends Notifier<bool> {
  @override
  bool build() => false;

  void mark() => state = true;

  void reset() => state = false;
}

/// Where the rating ask is on screen, when it's inside the Rendering sheet
/// (6.2a–c) rather than a sheet of its own.
enum InlineRatePhase { off, asking, thanks, feedback }

class InlineRate {
  final InlineRatePhase phase;
  final int rating;
  const InlineRate(this.phase, {this.rating = 5});
}

class InlineRateController extends Notifier<InlineRate> {
  @override
  InlineRate build() => const InlineRate(InlineRatePhase.off);

  void ask() => state = const InlineRate(InlineRatePhase.asking);
  void thank(int rating) => state = InlineRate(InlineRatePhase.thanks, rating: rating);
  void askWhatToFix(int rating) => state = InlineRate(InlineRatePhase.feedback, rating: rating);
  void close() => state = const InlineRate(InlineRatePhase.off);
}

final inlineRateProvider = NotifierProvider<InlineRateController, InlineRate>(InlineRateController.new);

/// The one-time rating ask, while the first render runs.
///
/// 6.2a — it takes the place of the ad in the Rendering sheet, so it never
/// covers the progress; if the person went back to work, it comes up as a
/// sheet of its own instead. The stars start empty; Rate waits for a pick.
/// 6.2c — four or five: "Thank you", then the store's own review card (the
/// same as Settings → Rate LastReel). 6.2b — one to three: "What should we
/// fix?", which reaches the team privately and never the store. Every
/// answer is logged to the team. Once someone has rated it never asks
/// again; "Not now" or a low rating can be asked again 30 days later, up to
/// [maxAsks] times in all (see [due]).
abstract final class ReviewPrompt {
  /// At or above this, the person is sent to the store; below, to the team.
  static const storeThreshold = 4;

  /// How long "Thank you" stays before the store's card opens.
  static const thanksPause = Duration(milliseconds: 1200);

  /// Between asks: "Not now" or a low rating waits this long.
  static const quiet = Duration(days: 30);

  /// Asked on its own at most this often per device, however it went.
  static const maxAsks = 3;

  /// Whether it may ask now: never again once someone has rated (4–5 went
  /// to the store, and asking again only annoys); otherwise 30 days after
  /// the last ask, and no more than [maxAsks] times in all.
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
    // The web has no store to rate in.
    if (kIsWeb || !due(store, now)) return;
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

  /// Settings → Rate LastReel: the same stars, asked because the person
  /// chose to — so it ignores whether the prompt already came up.
  static Future<void> askNow(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    container.read(analyticsProvider).logEvent('review_prompt_shown', {'source': 'settings'});
    await _askInSheet(context, container, whileRendering: false);
  }

  static Future<void> _askInSheet(BuildContext context, ProviderContainer container, {bool whileRendering = true}) async {
    final analytics = container.read(analyticsProvider);
    final rating = await showEcSheet<int>(context, builder: (_) => ReviewPromptSheet(whileRendering: whileRendering));
    if (rating == null) {
      await container.read(reviewPromptStoreProvider).recordAnswer(ReviewAnswer.later);
      return analytics.logEvent('review_prompt_later');
    }
    if (rating >= storeThreshold) return toStore(container, rating);

    analytics.logEvent('review_prompt_low', {'rating': rating});
    if (!context.mounted) return;
    final report = await showEcSheet<RatingFeedback>(context, builder: (_) => ReviewFeedbackSheet(rating: rating));
    sendToTeam(container, report, rating);
  }

  /// Four or five stars: logged to the team, then the store's review card.
  static Future<void> toStore(ProviderContainer container, int rating) async {
    container.read(analyticsProvider).logEvent('review_prompt_rate', {'rating': rating});
    await container.read(reviewPromptStoreProvider).recordAnswer(ReviewAnswer.rated);
    container.read(feedbackRepositoryProvider).submit(RatingFeedback(rating: rating));
    await container.read(settingsControllerProvider).rate();
  }

  /// One to three stars: the report, or on Skip the stars alone.
  static void sendToTeam(ProviderContainer container, RatingFeedback? report, int rating) {
    container.read(reviewPromptStoreProvider).recordAnswer(ReviewAnswer.low);
    container.read(feedbackRepositoryProvider).submit(report ?? RatingFeedback(rating: rating));
    // Raised from the root navigator's own overlay context, which can't
    // look itself up; show the thanks on that overlay directly.
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (report != null && overlay != null && overlay.mounted) {
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
    if (!mounted || !ReviewPrompt.due(ref.read(reviewPromptStoreProvider), ref.read(clockProvider)())) return;
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

/// 6.2a as a sheet of its own — for when the Rendering sheet isn't open.
class ReviewPromptSheet extends StatefulWidget {
  /// "While you wait" sits above the question only during a render.
  final bool whileRendering;
  const ReviewPromptSheet({super.key, this.whileRendering = true});

  @override
  State<ReviewPromptSheet> createState() => _ReviewPromptSheetState();
}

class _ReviewPromptSheetState extends State<ReviewPromptSheet> {
  int? _thanked;

  void _rate(int rating) {
    if (rating < ReviewPrompt.storeThreshold) return Navigator.of(context).pop(rating);
    // 6.2c — a moment of thanks before the store's card takes over.
    setState(() => _thanked = rating);
    Future.delayed(ReviewPrompt.thanksPause, () {
      if (mounted) Navigator.of(context).pop(rating);
    });
  }

  @override
  Widget build(BuildContext context) {
    return EcSheet(
      child: _thanked != null
          ? const RatingThanks()
          : RateQuestion(
              onRate: _rate,
              onLater: () => Navigator.of(context).pop(),
              whileRendering: widget.whileRendering,
            ),
    );
  }
}

/// "Would you rate LastReel?" — the stars, full to start, and the answer.
class RateQuestion extends StatefulWidget {
  final ValueChanged<int> onRate;
  final VoidCallback onLater;
  final bool whileRendering;

  const RateQuestion({super.key, required this.onRate, required this.onLater, this.whileRendering = true});

  @override
  State<RateQuestion> createState() => _RateQuestionState();
}

class _RateQuestionState extends State<RateQuestion> {
  /// No stars until the person picks some (6.2a); Rate waits for them.
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.whileRendering) ...[
          Text(caps('While you wait'), textAlign: TextAlign.center, style: t.eyebrow.copyWith(fontSize: 9.5)),
          const SizedBox(height: 8),
        ],
        EcHeadline(
          'Would you rate ',
          emphasis: 'LastReel?',
          style: t.displayM.copyWith(fontSize: 30),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'One tap. It goes straight to the people who build it.',
          textAlign: TextAlign.center,
          style: t.bodyS.copyWith(fontSize: 12.5, color: p.muted),
        ),
        const SizedBox(height: 8),
        StarRating(value: _rating, onChanged: (v) => setState(() => _rating = v)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(caps('Not great'), style: t.mono.copyWith(fontSize: 9.5, color: p.faint)),
              Text(caps('Love it'), style: t.mono.copyWith(fontSize: 9.5, color: p.faint)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        EcButton(
          label: 'Rate LastReel',
          size: EcButtonSize.medium,
          onPressed: _rating == 0 ? null : () => widget.onRate(_rating),
        ),
        EcButton(label: 'Not now', variant: EcButtonVariant.plain, expand: true, onPressed: widget.onLater),
      ],
    );
  }
}

/// 6.2c — "Thank you. Opening the review…", five stars lit.
class RatingThanks extends StatelessWidget {
  const RatingThanks({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (var i = 0; i < 5; i++) Icon(Icons.star_rounded, size: 28, color: p.accentSolid)],
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: EcHeadline(
              'Thank you. ',
              emphasis: 'Opening the review…',
              style: t.displayM.copyWith(fontSize: 26),
              textAlign: TextAlign.center,
            ),
          ),
        ],
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

  void _rate(int rating) {
    final container = ProviderScope.containerOf(context, listen: false);
    final controller = ref.read(inlineRateProvider.notifier);
    if (rating >= ReviewPrompt.storeThreshold) {
      controller.thank(rating);
      Future.delayed(ReviewPrompt.thanksPause, () async {
        await ReviewPrompt.toStore(container, rating);
        controller.close();
      });
    } else {
      ref.read(analyticsProvider).logEvent('review_prompt_low', {'rating': rating});
      controller.askWhatToFix(rating);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final phase = ref.watch(inlineRateProvider.select((s) => s.phase));
    if (phase != InlineRatePhase.asking && phase != InlineRatePhase.thanks) return widget.ad;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.accentLine, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x800C6EC8), offset: Offset(0, 16), blurRadius: 30, spreadRadius: -20)],
      ),
      child: phase == InlineRatePhase.thanks
          ? const RatingThanks()
          : RateQuestion(
              onRate: _rate,
              onLater: () {
                ref.read(analyticsProvider).logEvent('review_prompt_later');
                ref.read(reviewPromptStoreProvider).recordAnswer(ReviewAnswer.later);
                ref.read(inlineRateProvider.notifier).close();
              },
            ),
    );
  }
}

/// Five tappable stars; tapping the third makes it three. A slider to
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
      label: 'Rating',
      value: value == 0 ? 'No stars' : '$value of 5 stars',
      increasedValue: value < 5 ? '${value + 1} of 5 stars' : null,
      decreasedValue: value > 1 ? '${value - 1} of 5 stars' : null,
      onIncrease: value < 5 ? () => onChanged(value + 1) : null,
      onDecrease: value > 1 ? () => onChanged(value - 1) : null,
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                key: ValueKey('star-$i'),
                iconSize: 38,
                onPressed: () => onChanged(i),
                icon: i <= value
                    ? Icon(Icons.star_rounded, color: p.accentSolid)
                    : Icon(Icons.star_outline_rounded, color: p.faint),
              ),
          ],
        ),
      ),
    );
  }
}

/// 6.2b as a sheet of its own.
class ReviewFeedbackSheet extends StatelessWidget {
  final int rating;
  const ReviewFeedbackSheet({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return EcSheet(
      child: ReviewFeedbackForm(
        rating: rating,
        onSend: (report) => Navigator.of(context).pop(report),
        onSkip: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// 6.2b — one to three stars: what should we fix? Topics and a note go to
/// the team with the rating; nothing goes to the store.
class ReviewFeedbackForm extends StatefulWidget {
  final int rating;
  final ValueChanged<RatingFeedback> onSend;
  final VoidCallback onSkip;

  const ReviewFeedbackForm({super.key, required this.rating, required this.onSend, required this.onSkip});

  @override
  State<ReviewFeedbackForm> createState() => _ReviewFeedbackFormState();
}

class _ReviewFeedbackFormState extends State<ReviewFeedbackForm> {
  late int _rating = widget.rating;
  final _topics = <FeedbackTopic>{};
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(child: StarRating(value: _rating, onChanged: (v) => setState(() => _rating = v))),
            Text('$_rating of 5', style: t.mono.copyWith(fontSize: 11, color: p.muted)),
          ],
        ),
        const SizedBox(height: 6),
        EcHeadline('Sorry it fell short. ', emphasis: 'What should we fix?', style: t.displayM.copyWith(fontSize: 30)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final topic in FeedbackTopic.values)
              EcChip(
                label: _topics.contains(topic) ? '✓ ${topic.label}' : topic.label,
                selected: _topics.contains(topic),
                onTap: () => setState(() => _topics.contains(topic) ? _topics.remove(topic) : _topics.add(topic)),
              ),
          ],
        ),
        const SizedBox(height: 18),
        EcTextArea(controller: _message, label: 'Tell us more · optional', minLines: 3, maxLines: 6),
        const SizedBox(height: 10),
        Text(
          'Sent privately to the LastReel team with your rating and app version. Never posted to the store.',
          style: t.caption,
        ),
        const SizedBox(height: 18),
        EcButton(
          label: 'Send to the team',
          onPressed: () => widget.onSend(RatingFeedback(rating: _rating, topics: {..._topics}, message: _message.text)),
        ),
        EcButton(label: 'Skip', variant: EcButtonVariant.plain, expand: true, onPressed: widget.onSkip),
      ],
    );
  }
}
