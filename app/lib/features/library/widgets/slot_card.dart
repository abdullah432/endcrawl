import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_dashed_border.dart';

/// The next empty reel on the free plan (1.1) — "03 · *One slot left*".
///
/// Showing the cap as an empty slot means it's visible long before it blocks
/// anyone, instead of arriving as a surprise on the fourth project.
class SlotCard extends StatelessWidget {
  final int reel;
  final int slotsLeft;
  final VoidCallback onUpgrade;

  const SlotCard({super.key, required this.reel, required this.slotsLeft, required this.onUpgrade});

  static const _words = ['No', 'One', 'Two', 'Three'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final count = slotsLeft < _words.length ? _words[slotsLeft] : '$slotsLeft';
    return EcDashedBorder(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(reel.toString().padLeft(2, '0'), style: t.reel.copyWith(color: p.accentSolid)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count ${slotsLeft == 1 ? 'slot' : 'slots'} left',
                      style: t.barTitle.copyWith(fontSize: 20, fontStyle: FontStyle.italic, height: 1.1)),
                  const SizedBox(height: 2),
                  Text('Pro removes the cap and the ads.', style: t.caption),
                ],
              ),
            ),
            EcButton(label: 'Upgrade', variant: EcButtonVariant.ink, size: EcButtonSize.small, onPressed: onUpgrade),
          ],
        ),
      ),
    );
  }
}
