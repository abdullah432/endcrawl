import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_choice_card.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/entitlement.dart';
import '../controllers/plan_controller.dart';

/// 6.5 — LastReel Pro.
///
/// Three reasons in one headline: more projects, pro formats, no ads. The
/// table makes plain that editing is identical on both plans; only the
/// project cap and the export formats differ.
class ProSheet extends ConsumerWidget {
  const ProSheet({super.key});

  static Future<void> show(BuildContext context) => showEcSheet<void>(context, builder: (_) => const ProSheet());

  static const _comparison = <(String, String, String)>[
    ('Projects', '${Entitlement.freeProjectLimit}', 'Unlimited'),
    ('Ads', 'Shown', 'None'),
    ('Blocks, timing, look', 'Everything', 'Everything'),
    ('Codecs', 'H.264, HEVC', '+ ProRes, PNG'),
    ('Resolution', 'Up to 1080p', 'Up to 4K'),
    ('Pro render on Free', '1 per rewarded ad', 'Every render'),
    ('Watermark', 'None', 'None'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(planControllerProvider);
    final controller = ref.read(planControllerProvider.notifier);
    final p = context.palette;
    final t = context.type;
    final selected = state.selected;
    final periodLabel = selected.period == BillingPeriod.yearly ? 'yr' : 'mo';

    return EcSheet(
      maxHeightFraction: 0.94,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: EcCircleButton.glass(
            icon: Icons.close_rounded,
            size: 34,
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.message != null) ...[
              EcNotice(tone: EcTone.neutral, title: state.message!, icon: Icons.info_outline_rounded),
              const SizedBox(height: 10),
            ],
            EcButton(
              label: 'Start Pro — ${selected.price}/$periodLabel',
              busy: state.purchasing,
              onPressed: state.busy
                  ? null
                  : () async {
                      final ok = await controller.purchase();
                      if (ok && context.mounted) Navigator.of(context).pop();
                    },
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                EcButton(
                  label: 'Restore purchase',
                  variant: EcButtonVariant.plain,
                  size: EcButtonSize.small,
                  busy: state.restoring,
                  onPressed: state.busy ? null : controller.restore,
                ),
                EcButton(
                  label: 'Stay on Free',
                  variant: EcButtonVariant.text,
                  size: EcButtonSize.small,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EcEyebrow('LastReel Pro', color: p.accent),
                const SizedBox(height: 10),
                EcHeadline('Unlimited projects.\n', emphasis: 'Pro formats. No ads.', style: t.displayL.copyWith(fontSize: 44)),
                const SizedBox(height: 10),
                Text(
                  'Free has every block, timing and look tool, with H.264 and HEVC up to 1080p. Pro lifts the '
                  'three-project cap, unlocks ProRes, PNG and 4K on every render, and removes ads.',
                  style: t.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final offer in PlanOffer.all) ...[
            _OfferTile(offer: offer, selected: offer == selected, onTap: () => controller.select(offer)),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          _ComparisonTable(rows: _comparison),
        ],
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  final PlanOffer offer;
  final bool selected;
  final VoidCallback onTap;

  const _OfferTile({required this.offer, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return EcChoiceCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: selected ? p.primary : null,
              border: selected ? null : Border.all(color: p.line2, width: 1.5),
            ),
            child: selected ? Icon(Icons.check_rounded, size: 14, color: p.onInk) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(offer.period == BillingPeriod.yearly ? 'Yearly' : 'Monthly', style: t.titleS),
                    if (offer.badge != null) ...[const SizedBox(width: 6), EcGradientPill(offer.badge!)],
                  ],
                ),
                const SizedBox(height: 2),
                Text(offer.detail, style: t.caption),
              ],
            ),
          ),
          Text(offer.price, style: t.monoM.copyWith(fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final List<(String, String, String)> rows;
  const _ComparisonTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    Widget row(String a, String b, String c, {bool header = false}) {
      final base = header ? t.pill.copyWith(color: p.muted) : t.bodyS.copyWith(fontSize: 12);
      return Container(
        color: header ? p.tint : null,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: header ? 10 : 11),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(header ? a.toUpperCase() : a, style: header ? base : base.copyWith(color: p.ink2)),
            ),
            Expanded(
              flex: 2,
              child: Text(header ? b.toUpperCase() : b, style: base.copyWith(color: p.muted)),
            ),
            Expanded(
              flex: 2,
              child: Text(
                header ? c.toUpperCase() : c,
                style: header
                    ? base.copyWith(color: p.accent)
                    : base.copyWith(color: p.ink, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(EcRadius.card),
      ),
      child: Column(
        children: [
          row('Plan', 'Free', 'Pro', header: true),
          for (final (a, b, c) in rows) ...[Divider(height: 1, color: p.line), row(a, b, c)],
        ],
      ),
    );
  }
}
