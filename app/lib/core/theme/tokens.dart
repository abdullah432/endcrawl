import 'package:flutter/widgets.dart';

/// Semantic design tokens ported 1:1 from the EndCrawl design system's
/// CSS custom properties (`EndCrawl.dc.html` `:root`). Every color, space,
/// radius and motion value in the app should come from here.
class EcColors {
  EcColors._();

  static const bgStage = Color(0xFF08090B);
  static const surfaceCanvas = Color(0xFF0B0D10);
  static const surfaceSunken = Color(0xFF0E1114);
  static const surfaceRaised = Color(0xFF15181D);
  static const surfaceOverlay = Color(0xFF1B1F25);
  static const surfaceHi = Color(0xFF232830);

  static const borderHairline = Color(0xFF23272E);
  static const borderStrong = Color(0xFF343A44);

  static const accentPrimary = Color(0xFFD6A44F);
  static const accentHi = Color(0xFFE8BD6F);
  static const accentInk = Color(0xFF140F04);
  static const accentDim = Color(0xFF5E4A21);
  static const accentWash = Color(0x1FD6A44F); // rgba(214,164,79,.12)

  static const warn = Color(0xFFE2705C);
  static const warnWash = Color(0x1FE2705C); // rgba(226,112,92,.12)

  static const textPrimary = Color(0xFFF1F2F4);
  static const textSecondary = Color(0xFF9AA1AB);
  static const textTertiary = Color(0xFF6A7280);
  static const textDisabled = Color(0xFF4A515B);

  static const safeTitle = Color(0x80D6A44F); // rgba(214,164,79,.5)
  static const safeAction = Color(0x38FFFFFF); // rgba(255,255,255,.22)
}

class EcSpace {
  EcSpace._();
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s7 = 32.0;
  static const s8 = 40.0;
}

class EcRadius {
  EcRadius._();
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 22.0;
  static const full = 999.0;
}

class EcMotion {
  EcMotion._();
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 250);

  // cubic-bezier(.2,.8,.2,1)
  static const easeOut = Cubic(0.2, 0.8, 0.2, 1);
  // cubic-bezier(.2,1.25,.35,1) — overshoots, spring-like.
  static const easeSpring = Cubic(0.2, 1.25, 0.35, 1);
}

class EcFonts {
  EcFonts._();
  static const ui = 'IBM Plex Sans';
  static const mono = 'IBM Plex Mono';
  static const archivo = 'Archivo';
  static const archivoNarrow = 'Archivo Narrow';
  static const garamond = 'EB Garamond';
}
