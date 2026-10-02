import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';

/// The free plan's slots as segments — filled for each project in use: two
/// bars on 1.6, Settings (7.1) and the library's plan card (1.1a).
class PlanMeter extends StatelessWidget {
  final int used;
  final int limit;

  /// Bar height and the gap between bars — thinner inside a card (1.1a).
  final double thickness;
  final double gap;

  const PlanMeter({super.key, required this.used, required this.limit, this.thickness = 6, this.gap = 6});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '$used of $limit projects',
      child: Row(
        children: [
          for (var i = 0; i < limit; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(
              child: Container(
                height: thickness,
                decoration: BoxDecoration(
                  gradient: i < used ? p.primary : null,
                  color: i < used ? null : p.tint,
                  borderRadius: BorderRadius.circular(EcRadius.pill),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A "✓ benefit" line — the Pro card's bullets.
class PlanBenefit extends StatelessWidget {
  final String text;
  final bool included;

  const PlanBenefit(this.text, {super.key, this.included = true});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 16,
          child: Text(included ? '✓' : '✕',
              style: context.type.bodyS.copyWith(color: included ? p.ok : p.warn, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: context.type.bodyS)),
      ],
    );
  }
}
