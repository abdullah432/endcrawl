import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_chip.dart';
import '../../../core/widgets/ec_choice_card.dart';
import '../../../core/widgets/ec_dashed_border.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/entitlement.dart';
import '../controllers/plan_controller.dart';
import '../controllers/trial_offer_controller.dart';
import '../screens/pro_sheet.dart';

const _numberWords = ['zero', 'one', 'two', 'three', 'four', 'five'];
String _word(int n) => n < _numberWords.length ? _numberWords[n] : '$n';

/// "FREE PLAN ──── 1 OF 1 PROJECT USED" — between the user's work and the
/// trial offer, so the card reads as a plan, not a second project (1.1a).
class FreePlanDivider extends StatelessWidget {
  final int used;
  final int limit;
  const FreePlanDivider({super.key, required this.used, required this.limit});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = context.type.mono.copyWith(fontSize: 10, letterSpacing: 1.4, color: p.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Text('FREE PLAN', style: style),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: p.line)),
          const SizedBox(width: 10),
          Text('$used OF ${plural(limit, 'PROJECT')} USED', style: style),
        ],
      ),
    );
  }
}

/// 1.1a — the free-trial offer on a full free library. It must not look
/// like a project: an accent-washed card with a Pro pill, never a black
/// credit frame or a reel number. Yearly is preselected for its longer
/// trial; the button follows the selected plan. Where the store offers this
/// account no trial, the same card shows the plain prices.
class TrialOfferCard extends ConsumerStatefulWidget {
  final int limit;
  const TrialOfferCard({super.key, required this.limit});

  @override
  ConsumerState<TrialOfferCard> createState() => _TrialOfferCardState();
}

class _TrialOfferCardState extends ConsumerState<TrialOfferCard> {
  @override
  void initState() {
    super.initState();
    ref.read(trialOfferControllerProvider).shown();
  }

  Future<void> _start() async {
    final ok = await ref.read(planControllerProvider.notifier).purchase(source: PlanSource.library);
    if (!mounted) return;
    final message = ref.read(planControllerProvider).message;
    if (!ok && message != null) showEcToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final plan = ref.watch(planControllerProvider);
    final controller = ref.read(planControllerProvider.notifier);
    final offers = [...plan.offers]..sort((a, b) => b.period.index.compareTo(a.period.index)); // yearly first
    final selected = plan.selected;
    final trial = offers.any((o) => o.hasTrial);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // 165° in CSS: from the top, tilted slightly toward the right.
          begin: const Alignment(-0.26, -1),
          end: const Alignment(0.26, 1),
          colors: [Color.alphaBlend(p.accentWash, p.surface), p.surface],
        ),
        border: Border.all(color: p.accentLine, width: 1.5),
        borderRadius: BorderRadius.circular(EcRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(gradient: p.primary, borderRadius: BorderRadius.circular(EcRadius.pill)),
                child: Text(trial ? 'PRO · FREE TRIAL' : 'PRO',
                    style: t.mono.copyWith(fontSize: 10, letterSpacing: 1.2, color: p.onInk, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              EcCircleButton.tint(
                icon: Icons.close_rounded,
                size: 32,
                tooltip: 'Not now',
                onPressed: () => ref.read(trialOfferControllerProvider).dismiss(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          EcHeadline('Ready for', emphasis: 'reel ${_word(widget.limit + 1)}?', style: t.displayL.copyWith(fontSize: 32, height: 1.05)),
          const SizedBox(height: 8),
          Text(
            'Your free plan holds ${plural(widget.limit, 'project').replaceFirst('${widget.limit}', _word(widget.limit))}. '
            '${trial ? 'Try Pro free' : 'Go Pro'} to make as many as you like.',
            style: t.body.copyWith(fontSize: 13, color: p.ink2, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final perk in ['Unlimited projects', 'ProRes · PNG · 4K', 'No ads'])
                EcChip(label: perk, selected: false, onTap: null, height: 28),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (i, offer) in offers.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: EcChoiceCard(
                    selected: offer == selected,
                    onTap: () => controller.select(offer),
                    semanticLabel: offer.period == BillingPeriod.yearly ? 'Yearly' : 'Monthly',
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(offer.period == BillingPeriod.yearly ? 'Yearly' : 'Monthly',
                                  style: t.mono.copyWith(fontSize: 10, letterSpacing: 1.2, color: p.muted)),
                            ),
                            if (offer == selected) Icon(Icons.check_circle_rounded, size: 16, color: p.accent),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(offer.hasTrial ? '${offer.trialDays} days free' : '${offer.price}${offer.perPeriod}',
                            style: t.titleS.copyWith(fontSize: 14.5)),
                        const SizedBox(height: 2),
                        Text(offer.hasTrial ? 'then ${offer.price}${offer.perPeriod}' : 'Cancel anytime', style: t.caption),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          EcButton(
            label: selected?.ctaLabel ?? 'Loading plans…',
            busy: plan.purchasing,
            onPressed: selected == null || plan.busy ? null : _start,
          ),
          const SizedBox(height: 8),
          Text(selected?.hasTrial ?? trial ? 'No charge today · cancel anytime' : 'Cancel anytime',
              textAlign: TextAlign.center, style: t.caption),
        ],
      ),
    );
  }
}

/// On a Pro trial: a dashed reminder at the end of the list, so the trial's
/// end and the free limit are never a surprise (1.1).
class TrialReminderRow extends StatelessWidget {
  final int daysLeft;
  final DateTime endsAt;
  final int limit;

  const TrialReminderRow({super.key, required this.daysLeft, required this.endsAt, required this.limit});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return EcDashedBorder(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text('${daysLeft}d', style: t.reel.copyWith(color: p.accentSolid)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trial ends ${formatDayMonth(endsAt)}',
                      style: t.barTitle.copyWith(fontSize: 18, fontStyle: FontStyle.italic, height: 1.1)),
                  const SizedBox(height: 2),
                  Text(
                    'After that, ${plural(limit, 'project').replaceFirst('$limit', _word(limit))} '
                    '${limit == 1 ? 'stays' : 'stay'} free.',
                    style: t.caption,
                  ),
                ],
              ),
            ),
            EcButton(
              label: 'Plans',
              variant: EcButtonVariant.ink,
              size: EcButtonSize.small,
              onPressed: () => ProSheet.show(context, source: PlanSource.library),
            ),
          ],
        ),
      ),
    );
  }
}
