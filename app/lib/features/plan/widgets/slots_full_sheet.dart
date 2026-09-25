import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/entitlement.dart';
import 'plan_meter.dart';

enum SlotsFullChoice { upgrade, freeUp }

/// 1.6 — "+ New" when every free slot is used.
///
/// Opens with reassurance (nothing was deleted, nothing expires), then offers
/// the free way out before the paid one.
class SlotsFullSheet extends StatelessWidget {
  const SlotsFullSheet({super.key});

  static Future<SlotsFullChoice?> show(BuildContext context) {
    return showEcSheet<SlotsFullChoice>(context, builder: (_) => const SlotsFullSheet());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    const limit = Entitlement.freeProjectLimit;
    return EcSheet(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PlanMeter(used: limit, limit: limit),
          const SizedBox(height: 14),
          EcEyebrow('$limit of $limit slots used', color: p.accent),
          const SizedBox(height: 8),
          EcHeadline('The free plan keeps', emphasis: 'three projects.', style: t.displayL.copyWith(fontSize: 32, height: 1.05)),
          const SizedBox(height: 10),
          Text('Nothing was deleted and nothing expires. To start a fourth, free up a slot or lift the cap.',
              style: t.body.copyWith(fontSize: 13)),
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
                    Text('${PlanOffer.monthly.price}/mo', style: t.mono.copyWith(fontSize: 12, color: p.ink2)),
                  ],
                ),
                const SizedBox(height: 12),
                const PlanBenefit('Unlimited projects and render history'),
                const SizedBox(height: 8),
                const PlanBenefit('No ads anywhere in the app'),
                const SizedBox(height: 14),
                EcButton(
                  label: 'Upgrade to Pro',
                  size: EcButtonSize.medium,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(SlotsFullChoice.upgrade),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          EcButton.secondary(
            label: 'Free up a slot',
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
