import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';

/// The free plan's slots as segments — filled for each project in use.
/// On 1.6 all three are filled; on Settings (7.1) it's "2 of 3".
class PlanMeter extends StatelessWidget {
  final int used;
  final int limit;

  const PlanMeter({super.key, required this.used, required this.limit});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '$used of $limit projects',
      child: Row(
        children: [
          for (var i = 0; i < limit; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 6,
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
