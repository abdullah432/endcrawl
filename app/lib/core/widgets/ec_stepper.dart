import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import 'ec_scaffold.dart';

/// "− value +" — head/tail black, hold length, spacer, runtime nudges.
///
/// [label] puts a caption above it, in the white card the design uses on
/// 5.1; without one it renders bare, for use inside another card.
class EcStepper extends StatelessWidget {
  final String display;
  final VoidCallback? onDec;
  final VoidCallback? onInc;
  final String? label;
  final double buttonSize;

  const EcStepper({
    super.key,
    required this.display,
    required this.onDec,
    required this.onInc,
    this.label,
    this.buttonSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final row = Row(
      children: [
        EcCircleButton.tint(icon: Icons.remove_rounded, onPressed: onDec, size: buttonSize, tooltip: 'Decrease'),
        Expanded(child: Text(display, textAlign: TextAlign.center, style: t.monoM)),
        EcCircleButton.tint(icon: Icons.add_rounded, onPressed: onInc, size: buttonSize, tooltip: 'Increase'),
      ],
    );
    if (label == null) return row;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label!, style: t.caption),
          const SizedBox(height: 8),
          row,
        ],
      ),
    );
  }
}
