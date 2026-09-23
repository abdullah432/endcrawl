import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme_context.dart';

/// The ENDCRAWL wordmark: Archivo Narrow 700, tracked .32 em, upper case.
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
      label: 'EndCrawl',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'ENDCRAWL',
          style: GoogleFonts.archivoNarrow(
            fontSize: size,
            fontWeight: FontWeight.w700,
            letterSpacing: size * 0.32,
            color: color ?? context.palette.ink,
          ),
        ),
      ),
    );
  }
}
