import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ec_palette.dart';

/// The app's type scale, as a [ThemeExtension].
///
/// Four families, each with one job (from the design's Foundations board):
/// - **Instrument Serif** — screen and sheet titles, reel numbers.
/// - **Archivo** — all interface text.
/// - **JetBrains Mono** — timecodes, rates, eyebrows and status pills.
/// - **Archivo Narrow** — credits only (the roll itself, via `CreditFace`).
///
/// Every style carries its default colour, so a call site states only what
/// differs: `context.type.caption` is already muted, `context.type.body`
/// already ink. That keeps the 20-odd named styles below the only place a
/// font size is written down.
@immutable
class EcType extends ThemeExtension<EcType> {
  // Serif display.
  final TextStyle displayXL; // 52 — "Projects"
  final TextStyle displayL; // 42 — onboarding heroes, screen titles
  final TextStyle displayM; // 30 — sheet titles
  final TextStyle displayS; // 26 — sheet headers naming a project
  final TextStyle barTitle; // 22 — centred top-bar title
  final TextStyle reel; // 24 — "01" reel numbers

  // Archivo interface.
  final TextStyle titleM; // 16 / 600 — card titles
  final TextStyle titleS; // 14.5 / 600 — compact rows
  final TextStyle row; // 14.5 / 500 — settings and sheet rows
  final TextStyle button; // 15 / 700 — primary button
  final TextStyle buttonSmall; // 14 / 600
  final TextStyle bodyL; // 15 — field values
  final TextStyle body; // 13.5 — paragraphs
  final TextStyle bodyS; // 12.5
  final TextStyle label; // 12 / 600 — field labels
  final TextStyle caption; // 11.5 — secondary line under a row
  final TextStyle fine; // 11 — legal lines

  // JetBrains Mono.
  final TextStyle eyebrow; // 10, caps, tracked — "REEL · 2 OF 3"
  final TextStyle section; // 9.5, caps, tracked — group headers
  final TextStyle pill; // 9, caps — status pills
  final TextStyle code; // 10 / 500 — "CST" code tiles
  final TextStyle mono; // 11 — inline readouts
  final TextStyle monoM; // 14 — steppers
  final TextStyle timecode; // 30 / 500 — the runtime input

  const EcType({
    required this.displayXL,
    required this.displayL,
    required this.displayM,
    required this.displayS,
    required this.barTitle,
    required this.reel,
    required this.titleM,
    required this.titleS,
    required this.row,
    required this.button,
    required this.buttonSmall,
    required this.bodyL,
    required this.body,
    required this.bodyS,
    required this.label,
    required this.caption,
    required this.fine,
    required this.eyebrow,
    required this.section,
    required this.pill,
    required this.code,
    required this.mono,
    required this.monoM,
    required this.timecode,
  });

  factory EcType.from(EcPalette p) {
    TextStyle serif(double size, {double height = 1}) =>
        GoogleFonts.instrumentSerif(fontSize: size, height: height, color: p.ink, letterSpacing: -0.01 * size);
    TextStyle ui(double size, {FontWeight weight = FontWeight.w400, Color? color, double? height}) =>
        GoogleFonts.archivo(
          fontSize: size,
          fontWeight: weight,
          color: color ?? p.ink,
          height: height,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    TextStyle mono(double size, {FontWeight weight = FontWeight.w400, Color? color, double tracking = 0}) =>
        GoogleFonts.jetBrainsMono(
          fontSize: size,
          fontWeight: weight,
          color: color ?? p.ink,
          letterSpacing: tracking * size,
        );

    return EcType(
      displayXL: serif(52, height: 0.9),
      displayL: serif(42),
      displayM: serif(30),
      displayS: serif(26),
      barTitle: serif(22),
      reel: serif(24, height: 1).copyWith(color: p.muted),
      titleM: ui(16, weight: FontWeight.w600),
      titleS: ui(14.5, weight: FontWeight.w600),
      row: ui(14.5, weight: FontWeight.w500),
      button: ui(15, weight: FontWeight.w700),
      buttonSmall: ui(14, weight: FontWeight.w600),
      bodyL: ui(15),
      body: ui(13.5, color: p.ink2, height: 1.5),
      bodyS: ui(12.5, color: p.ink2, height: 1.45),
      label: ui(12, weight: FontWeight.w600, color: p.ink2),
      caption: ui(11.5, color: p.muted, height: 1.35),
      fine: ui(11, color: p.muted, height: 1.5),
      eyebrow: mono(10, color: p.muted, tracking: 0.14),
      section: mono(9.5, color: p.muted, tracking: 0.14),
      pill: mono(9, tracking: 0.1),
      code: mono(10, weight: FontWeight.w500, color: p.accent),
      mono: mono(11, color: p.muted),
      monoM: mono(14),
      timecode: mono(30, weight: FontWeight.w500, tracking: 0.02),
    );
  }

  @override
  EcType copyWith() => this;

  @override
  EcType lerp(covariant ThemeExtension<EcType>? other, double t) {
    if (other is! EcType) return this;
    return t < 0.5 ? this : other;
  }
}

/// Upper-cases text that the design sets with `text-transform: uppercase`.
///
/// Flutter has no text-transform, so the mono eyebrows and pills call this
/// at the call site; keeping it named makes the intent searchable.
String caps(String text) => text.toUpperCase();
