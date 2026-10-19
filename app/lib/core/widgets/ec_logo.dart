import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_context.dart';

/// The supplied app mark with the LASTREEL wordmark, shared by every layout.
///
/// The one place the wordmark is drawn, at whatever [size] a screen needs.
/// It scales down rather than clipping if a narrow layout can't fit it.
class EcLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const EcLogo({super.key, this.size = 14, this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'LastReel',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(size * .5),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: size * 2.4,
                height: size * 2.4,
                cacheWidth: 128,
                excludeFromSemantics: true,
              ),
            ),
            SizedBox(width: size * .65),
            Text(
              'LASTREEL',
              style: GoogleFonts.archivoNarrow(
                fontSize: size,
                fontWeight: FontWeight.w700,
                letterSpacing: size * 0.32,
                color: color ?? context.palette.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
