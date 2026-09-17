import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Global MaterialApp theme. EndCrawl is a single, fixed dark theme — the
/// brief explicitly avoids a second accent or a light mode, so this is not
/// a light/dark switch, just the one cinema-grade look.
ThemeData buildEndcrawlTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final uiTextTheme = GoogleFonts.ibmPlexSansTextTheme(base.textTheme).apply(
    bodyColor: EcColors.textPrimary,
    displayColor: EcColors.textPrimary,
  );

  return base.copyWith(
    scaffoldBackgroundColor: EcColors.bgStage,
    canvasColor: EcColors.surfaceCanvas,
    textTheme: uiTextTheme,
    colorScheme: base.colorScheme.copyWith(
      primary: EcColors.accentPrimary,
      secondary: EcColors.accentPrimary,
      surface: EcColors.surfaceRaised,
      error: EcColors.warn,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: EcColors.borderHairline,
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: EcColors.accentPrimary,
      thumbColor: EcColors.accentPrimary,
      inactiveTrackColor: EcColors.surfaceHi,
      overlayColor: EcColors.accentWash,
    ),
  );
}

/// Monospace text style helper (IBM Plex Mono), used for timecodes,
/// pixel-per-frame readouts and every other numeric/technical readout.
TextStyle ecMono(
  double size, {
  Color color = EcColors.textPrimary,
  FontWeight weight = FontWeight.w400,
  double? letterSpacing,
}) {
  return GoogleFonts.ibmPlexMono(
    fontSize: size,
    color: color,
    fontWeight: weight,
    letterSpacing: letterSpacing,
  );
}

TextStyle ecUi(
  double size, {
  Color color = EcColors.textPrimary,
  FontWeight weight = FontWeight.w400,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.ibmPlexSans(
    fontSize: size,
    color: color,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
  );
}

/// The credit-roll faces shipped with the app (distinct from the UI chrome
/// face). `creditFace` selects one of these for the actual roll content.
enum CreditFace { grotesque, serif, condensed }

extension CreditFaceX on CreditFace {
  TextStyle textStyle({
    required double size,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w400,
    double? letterSpacing,
  }) {
    switch (this) {
      case CreditFace.grotesque:
        return GoogleFonts.archivo(
          fontSize: size,
          color: color,
          fontWeight: weight,
          letterSpacing: letterSpacing,
        );
      case CreditFace.serif:
        return GoogleFonts.ebGaramond(
          fontSize: size,
          color: color,
          fontWeight: weight,
          letterSpacing: letterSpacing,
        );
      case CreditFace.condensed:
        return GoogleFonts.archivoNarrow(
          fontSize: size,
          color: color,
          fontWeight: weight,
          letterSpacing: letterSpacing,
        );
    }
  }

  String get label => switch (this) {
        CreditFace.grotesque => 'Grotesque · Archivo',
        CreditFace.serif => 'Transitional serif · EB Garamond',
        CreditFace.condensed => 'Condensed · Archivo Narrow',
      };
}
