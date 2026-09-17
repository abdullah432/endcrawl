import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../project/models/credit_block.dart';
import '../../project/models/roll_engine.dart';

/// Non-scrolling hold cards (studio logo, "in loving memory", copyright)
/// that interrupt the roll — each one is stacked full-bleed over the
/// canvas and only the currently-active one is opaque, per [paint].
class HoldOverlay extends StatelessWidget {
  final List<HoldBlock> holds;
  final RollGeometry geometry;
  final RollPaint paint;

  const HoldOverlay({super.key, required this.holds, required this.geometry, required this.paint});

  @override
  Widget build(BuildContext context) {
    final base = geometry.base;
    return Stack(
      children: [
        for (final h in holds)
          IgnorePointer(
            child: Opacity(
              opacity: paint.holdId == h.id ? paint.holdOpacity : 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < h.lines.length; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: base * .5),
                        child: Text(
                          h.lines[i],
                          textAlign: TextAlign.center,
                          style: geometry.face.textStyle(
                            size: i == 0 ? base * 1.05 : base * .9,
                            letterSpacing: (i == 0 ? base * 1.05 : base * .9) * .2,
                            color: Colors.white.withValues(alpha: i == 0 ? 1 : .8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
