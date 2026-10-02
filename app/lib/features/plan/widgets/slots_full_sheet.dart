import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/entitlement.dart';
import '../controllers/plan_controller.dart';
import 'plan_meter.dart';

enum SlotsFullChoice { upgrade, freeUp }

/// 1.6 — "+ New" when the free project slots are used.
///
/// Opens with reassurance (nothing was deleted, nothing expires), then
/// offers a free trial rather than an instant charge; freeing up a slot
/// stays as the no-commitment way out. Where the store has no trial for
/// this account, the Pro card offers the plan plainly.
class SlotsFullSheet extends ConsumerWidget {
  const SlotsFullSheet({super.key});

  static Future<SlotsFullChoice?> show(BuildContext context) {
    return showEcSheet<SlotsFullChoice>(context, builder: (_) => const SlotsFullSheet());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    const limit = Entitlement.freeProjectLimit;
    final offers = ref.watch(planControllerProvider).offers;
    final monthly = offers.where((o) => o.period == BillingPeriod.monthly && o.hasTrial).firstOrNull;
    final yearly = offers.where((o) => o.period == BillingPeriod.yearly && o.hasTrial).firstOrNull;
    final trial = monthly != null || yearly != null;
    final trials = [
      if (monthly != null) '${monthly.trialDays} days free on monthly (${monthly.price})',
      if (yearly != null) '${yearly.trialDays} days free on yearly (${yearly.price})',
    ];
    return EcSheet(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PlanMeter(used: limit, limit: limit),
          const SizedBox(height: 14),
          EcEyebrow('$limit of $limit ${limit == 1 ? 'project' : 'projects'} used', color: p.accent),
          const SizedBox(height: 8),
          EcHeadline('The free plan keeps', emphasis: '${Entitlement.freeProjectsInWords}.',
              style: t.displayL.copyWith(fontSize: 32, height: 1.05)),
          const SizedBox(height: 10),
          Text(
            trial
                ? 'Nothing was deleted and nothing expires. To start another, free up ${_slot(limit)} or try Pro free — '
                    'you won’t be charged until the trial ends.'
                : 'Nothing was deleted and nothing expires. To start another, free up ${_slot(limit)} or lift the cap.',
            style: t.body.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border.all(color: p.accentLine),
              borderRadius: BorderRadius.circular(EcRadius.card),
              boxShadow: const [BoxShadow(color: Color(0x800C6EC8), offset: Offset(0, 14), blurRadius: 30, spreadRadius: -20)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(child: Text('LastReel Pro', style: t.titleM.copyWith(fontWeight: FontWeight.w700))),
                    Text(trial ? 'Try free' : 'View plans',
                        style: t.mono.copyWith(fontSize: 12, color: trial ? p.accent : p.ink2)),
                  ],
                ),
                const SizedBox(height: 12),
                const PlanBenefit('Unlimited projects and render history'),
                const SizedBox(height: 8),
                const PlanBenefit('ProRes, PNG alpha and 4K exports'),
                const SizedBox(height: 8),
                const PlanBenefit('No ads anywhere in the app'),
                if (trial) ...[
                  const SizedBox(height: 10),
                  Text('${trials.join(', ')}. Cancel before it ends and pay nothing.',
                      style: t.caption.copyWith(height: 1.45)),
                ],
                const SizedBox(height: 14),
                EcButton(
                  label: trial ? 'Start free trial' : 'Upgrade to Pro',
                  size: EcButtonSize.medium,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(SlotsFullChoice.upgrade),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          EcButton.secondary(
            label: 'Free up ${_slot(limit)}',
            size: EcButtonSize.medium,
            expand: true,
            onPressed: () => Navigator.of(context).pop(SlotsFullChoice.freeUp),
          ),
          const SizedBox(height: 8),
          Text('Returns to the list with delete on each row.', textAlign: TextAlign.center, style: t.caption),
        ],
      ),
    );
  }
}

String _slot(int limit) => limit == 1 ? 'the slot' : 'a slot';
