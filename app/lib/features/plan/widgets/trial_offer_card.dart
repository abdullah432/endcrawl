import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_dashed_border.dart';
import '../controllers/plan_controller.dart';
import '../controllers/trial_offer_controller.dart';
import '../screens/pro_sheet.dart';
import 'plan_meter.dart';

/// 1.1a — the plan card pinned under a full free library, in the ad's
/// place. It reads as the plan, not a third project: a white card with the
/// slot meter and one way forward. Picking monthly or yearly happens only on
/// 6.5, so the library shows no prices. Where the store has no trial for
/// this account, the same card offers the plans plainly.
class TrialOfferCard extends ConsumerStatefulWidget {
  final int used;
  final int limit;
  const TrialOfferCard({super.key, required this.used, required this.limit});

  @override
  ConsumerState<TrialOfferCard> createState() => _TrialOfferCardState();
}

class _TrialOfferCardState extends ConsumerState<TrialOfferCard> {
  @override
  void initState() {
    super.initState();
    ref.read(trialOfferControllerProvider).shown();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final offers = ref.watch(planControllerProvider.select((s) => s.offers));
    // Until the store answers, assume the trial — most accounts have one.
    final trial = offers.isEmpty || offers.any((o) => o.hasTrial);
    final limit = widget.limit;
    final mono = t.mono.copyWith(fontSize: 9.5, letterSpacing: 1.3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x59141428), offset: Offset(0, 14), blurRadius: 30, spreadRadius: -20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('FREE PLAN', style: mono.copyWith(color: p.muted))),
              Text('${widget.used} OF ${plural(limit, 'PROJECT', 'PROJECTS')}', style: mono.copyWith(color: p.ink2, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 8),
          PlanMeter(used: widget.used, limit: limit, thickness: 4, gap: 4),
          const SizedBox(height: 14),
          Text(
            switch (limit) {
              1 => 'Your free project is in use',
              2 => 'Both free projects are in use',
              _ => 'All ${numberWord(limit)} free projects are in use',
            },
            style: t.titleS.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.25),
          ),
          const SizedBox(height: 4),
          Text(
            '${trial ? 'Try Pro free' : 'Go Pro'} for unlimited projects, ProRes and 4K exports, and no ads.',
            style: t.body.copyWith(fontSize: 12.5, color: p.ink2, height: 1.45),
          ),
          const SizedBox(height: 14),
          EcButton(
            label: trial ? 'Start free trial' : 'See Pro plans',
            size: EcButtonSize.medium,
            expand: true,
            onPressed: () => ProSheet.show(context, source: PlanSource.library),
          ),
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
                    'After that, ${plural(limit, 'project').replaceFirst('$limit', numberWord(limit))} '
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
