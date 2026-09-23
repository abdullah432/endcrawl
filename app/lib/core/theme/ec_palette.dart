import 'package:flutter/material.dart';

/// The app's colour roles, as a [ThemeExtension].
///
/// Ported from the v2 design's `:root` custom properties (T4 Aurora Noir,
/// light). Screens read colours through `context.palette`, never through a
/// static, so the theme is a value that can be swapped — a dark variant is a
/// second instance of this class, not a rewrite of every screen.
///
/// Names follow the design's own vocabulary (`ink`, `muted`, `glass`, `tint`)
/// so a value can be traced from the design file to the code by name.
@immutable
class EcPalette extends ThemeExtension<EcPalette> {
  /// The screen ground — the warm off-white under the two colour blooms.
  final Color ground;

  /// Bloom colours painted over [ground] (see `EcGround`).
  final Color bloomCool;
  final Color bloomWarm;

  /// Bottom sheets.
  final Color sheet;

  /// Opaque surface for inputs and elevated cards.
  final Color surface;

  /// Translucent card fill — "glass". Its border is [glassEdge].
  final Color glass;
  final Color glassStrong;
  final Color glassEdge;

  final Color ink;
  final Color ink2;
  final Color muted;
  final Color faint;

  final Color line;
  final Color line2;

  /// A 5 % ink wash: icon buttons, segmented tracks, meter tracks.
  final Color tint;

  /// Scrim behind modal sheets.
  final Color scrim;

  /// The primary action gradient (135°, azure → violet).
  final Gradient primary;

  /// The accent used for links, selected chips and code tiles.
  final Color accent;
  final Color accentSolid;
  final Color accentWash;
  final Color accentLine;

  /// Accent readable on black (monitor overlays, dark toasts).
  final Color accentOnBlack;

  final Color warn;
  final Color warnFill;
  final Color warnWash;
  final Color warnLine;

  final Color ok;
  final Color okWash;
  final Color okOnBlack;

  /// The monitor is black in every theme — it previews a delivery file.
  final Color monitor;

  /// Solid ink surfaces with white text: toasts, bulk bar, "Upgrade" pills.
  final Color inkSurface;
  final Color onInk;

  final List<BoxShadow> primaryShadow;
  final List<BoxShadow> glassShadow;
  final List<BoxShadow> rowShadow;
  final List<BoxShadow> sheetShadow;
  final List<BoxShadow> toastShadow;

  const EcPalette({
    required this.ground,
    required this.bloomCool,
    required this.bloomWarm,
    required this.sheet,
    required this.surface,
    required this.glass,
    required this.glassStrong,
    required this.glassEdge,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.faint,
    required this.line,
    required this.line2,
    required this.tint,
    required this.scrim,
    required this.primary,
    required this.accent,
    required this.accentSolid,
    required this.accentWash,
    required this.accentLine,
    required this.accentOnBlack,
    required this.warn,
    required this.warnFill,
    required this.warnWash,
    required this.warnLine,
    required this.ok,
    required this.okWash,
    required this.okOnBlack,
    required this.monitor,
    required this.inkSurface,
    required this.onInk,
    required this.primaryShadow,
    required this.glassShadow,
    required this.rowShadow,
    required this.sheetShadow,
    required this.toastShadow,
  });

  static const light = EcPalette(
    ground: Color(0xFFF4EEE5),
    bloomCool: Color(0x420C8CE9), // rgba(12,140,233,.26)
    bloomWarm: Color(0x24FF5FC4), // rgba(255,95,196,.14)
    sheet: Color(0xFFFBF8F3),
    surface: Color(0xFFFFFFFF),
    glass: Color(0x9EFFFFFF), // white 62 %
    glassStrong: Color(0xB8FFFFFF), // white 72 % — settings groups
    glassEdge: Color(0xFFFFFFFF),
    ink: Color(0xFF1A1612),
    ink2: Color(0xFF3D352C),
    muted: Color(0xFF6B6053),
    faint: Color(0xFFA39888),
    line: Color(0x1A1A1612), // 10 %
    line2: Color(0x331A1612), // 20 %
    tint: Color(0x0D1A1612), // 5 %
    scrim: Color(0x6B1A1612), // 42 %
    primary: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0A7BD0), Color(0xFF6A5AF5)],
    ),
    accent: Color(0xFF0B6FB8),
    accentSolid: Color(0xFF0A7BD0),
    accentWash: Color(0x170C8CE9), // 9 %
    accentLine: Color(0x730A7BD0), // 45 %
    accentOnBlack: Color(0xFF8CCBFA),
    warn: Color(0xFFB83A26),
    warnFill: Color(0xFFD2432E),
    warnWash: Color(0x14D2432E), // 8 %
    warnLine: Color(0x52D2432E), // 32 %
    ok: Color(0xFF157A57),
    okWash: Color(0x1A16875F), // 10 %
    okOnBlack: Color(0xFF2BE0A0),
    monitor: Color(0xFF000000),
    inkSurface: Color(0xFF1A1612),
    onInk: Color(0xFFFFFFFF),
    primaryShadow: [
      BoxShadow(color: Color(0x8C0C6EC8), offset: Offset(0, 10), blurRadius: 24, spreadRadius: -8),
    ],
    glassShadow: [
      BoxShadow(color: Color(0x59503C1E), offset: Offset(0, 14), blurRadius: 30, spreadRadius: -18),
    ],
    rowShadow: [
      BoxShadow(color: Color(0x14503C1E), offset: Offset(0, 1), blurRadius: 2),
    ],
    sheetShadow: [
      BoxShadow(color: Color(0x661A1612), offset: Offset(0, -20), blurRadius: 50, spreadRadius: -20),
    ],
    toastShadow: [
      BoxShadow(color: Color(0x991A1612), offset: Offset(0, 18), blurRadius: 36, spreadRadius: -14),
    ],
  );

  @override
  EcPalette copyWith() => this;

  /// Palettes are swapped whole (light ↔ a future dark), never tweened
  /// field-by-field, so interpolation just picks a side.
  @override
  EcPalette lerp(covariant ThemeExtension<EcPalette>? other, double t) {
    if (other is! EcPalette) return this;
    return t < 0.5 ? this : other;
  }
}
