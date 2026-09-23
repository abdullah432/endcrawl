import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/models/credit_face.dart';
import 'ec_palette.dart';
import 'ec_type.dart';
import 'tokens.dart';

/// The app's single `ThemeData`, built from [EcPalette] and [EcType].
///
/// Material's own component themes are set from the same values, so a plain
/// `TextField`, `Switch` or `SnackBar` already looks like EndCrawl and the
/// shared widgets in `core/widgets` only add what Material can't express
/// (gradient fills, glass, pill geometry).
ThemeData buildEndcrawlTheme({EcPalette palette = EcPalette.light}) {
  final type = EcType.from(palette);
  final base = ThemeData.light(useMaterial3: true);
  final textTheme = GoogleFonts.archivoTextTheme(base.textTheme).apply(
    bodyColor: palette.ink,
    displayColor: palette.ink,
  );

  return base.copyWith(
    extensions: [palette, type],
    scaffoldBackgroundColor: palette.ground,
    canvasColor: palette.sheet,
    textTheme: textTheme,
    colorScheme: base.colorScheme.copyWith(
      primary: palette.accentSolid,
      onPrimary: palette.onInk,
      secondary: palette.accent,
      surface: palette.sheet,
      onSurface: palette.ink,
      error: palette.warnFill,
      outline: palette.line2,
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerColor: palette.line,
    dividerTheme: DividerThemeData(color: palette.line, thickness: 1, space: 1),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: palette.accentSolid,
      selectionColor: palette.accentWash,
      selectionHandleColor: palette.accentSolid,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(palette.surface),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? palette.accentSolid : palette.line2,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: palette.accentSolid,
      thumbColor: palette.surface,
      inactiveTrackColor: palette.tint,
      overlayColor: palette.accentWash,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      modalBackgroundColor: Colors.transparent,
      modalBarrierColor: palette.scrim,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.inkSurface,
      contentTextStyle: type.body.copyWith(color: palette.onInk),
      actionTextColor: palette.accentOnBlack,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.card)),
      elevation: 0,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.accentSolid),
  );
}

/// Maps the domain's [CreditFace] onto the concrete typefaces it ships as.
/// The enum itself lives in `domain/models/credit_face.dart` because it is
/// stored in the project document; only this rendering of it is theme code.
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
}
