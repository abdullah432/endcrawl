import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A compact "− value +" stepper used for head/tail black, hold/fade
/// durations, spacer length and title scale.
class EcStepper extends StatelessWidget {
  final String display;
  final VoidCallback onDec;
  final VoidCallback onInc;

  const EcStepper({super.key, required this.display, required this.onDec, required this.onInc});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EcColors.surfaceRaised,
        border: Border.all(color: EcColors.borderHairline),
        borderRadius: BorderRadius.circular(EcRadius.md),
      ),
      padding: const EdgeInsets.all(EcSpace.s2),
      child: Row(
        children: [
          _btn(Icons.remove, onDec),
          Expanded(
            child: Text(
              display,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 15, color: EcColors.textPrimary),
            ),
          ),
          _btn(Icons.add, onInc),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return Material(
      color: EcColors.surfaceHi,
      borderRadius: BorderRadius.circular(EcRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EcRadius.sm),
        child: SizedBox(width: 40, height: 36, child: Icon(icon, size: 16, color: EcColors.textPrimary)),
      ),
    );
  }
}
