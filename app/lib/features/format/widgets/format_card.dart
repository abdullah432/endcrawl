import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../project/models/canvas_format.dart';

class FormatCard extends StatelessWidget {
  final CanvasFormat format;
  final bool selected;
  final VoidCallback onTap;

  const FormatCard({super.key, required this.format, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ar = format.w / format.h;
    const chipMax = 30.0;
    final chipW = ar >= 1 ? chipMax : chipMax * ar;
    final chipH = ar >= 1 ? chipMax / ar : chipMax;

    return Material(
      color: selected ? EcColors.accentWash : EcColors.surfaceRaised,
      borderRadius: BorderRadius.circular(EcRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EcRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(EcSpace.s3),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? EcColors.accentPrimary : EcColors.borderHairline),
            borderRadius: BorderRadius.circular(EcRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 34,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: chipW,
                    height: chipH,
                    decoration: BoxDecoration(
                      border: Border.all(color: selected ? EcColors.accentPrimary : EcColors.borderStrong, width: 1.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(format.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: EcColors.textPrimary)),
              const SizedBox(height: 2),
              Text(format.sub, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 10, color: EcColors.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }
}
