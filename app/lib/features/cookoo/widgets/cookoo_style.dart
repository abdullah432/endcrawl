import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_context.dart';

/// Type for the COOKOO card and its screens, on the app's own families:
/// Instrument Serif *italic* for headlines and buttons, the app's mono for
/// labels, Archivo for the rest. Colours come from `context.palette`, so a
/// dark palette carries over without changes here.
extension CookooStyle on BuildContext {
  /// The real italic cut — `copyWith(fontStyle: italic)` on the app's
  /// upright serif would only slant it.
  TextStyle cookooSerif(double size, {double height = 1.05, Color? color}) => GoogleFonts.instrumentSerif(
    fontSize: size,
    height: height,
    fontStyle: FontStyle.italic,
    color: color ?? palette.ink,
  );

  /// Mono caps label; [tracking] is in logical pixels, as in the design.
  TextStyle cookooMono(double size, {double tracking = 0.8, Color? color}) =>
      type.eyebrow.copyWith(fontSize: size, letterSpacing: tracking, color: color ?? palette.muted, height: 1.2);

  TextStyle cookooUi(double size, {FontWeight weight = FontWeight.w400, Color? color, double? height}) =>
      type.bodyL.copyWith(fontSize: size, fontWeight: weight, color: color ?? palette.ink, height: height);
}

/// The 44 px-tall muted text link with a trailing icon — "See our work on
/// cookoo.dev ↗".
class CookooTextLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const CookooTextLink({super.key, required this.label, required this.onTap, this.icon = Icons.open_in_new});

  @override
  Widget build(BuildContext context) {
    final muted = context.palette.muted;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: context.cookooUi(14, weight: FontWeight.w600, color: muted),
                ),
              ),
              const SizedBox(width: 5),
              Icon(icon, size: 16, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The solid ink pill with a serif italic label — "Tell us your idea →",
/// "Send my idea", "Back to LastReel".
class CookooInkButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final double height;
  final double fontSize;
  final double iconSize;
  final bool busy;
  final VoidCallback? onPressed;

  const CookooInkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
    this.fontSize = 23,
    this.iconSize = 18,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled || busy ? 1 : 0.45,
        child: Material(
          color: p.inkSurface,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Center(
                child: busy
                    ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.onInk))
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(label, style: context.cookooSerif(fontSize, height: 1, color: p.onInk)),
                              if (icon != null) ...[
                                const SizedBox(width: 8),
                                Icon(icon, size: iconSize, color: p.onInk),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
