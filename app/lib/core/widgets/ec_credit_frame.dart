import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/ec_type.dart';
import '../theme/theme_context.dart';
import '../theme/tokens.dart';

/// A small black monitor frame — the "credit frame" every project card,
/// the welcome hero and the action sheet thumbnail are built on.
///
/// The monitor is black in every theme because it previews a delivery file.
/// Overlays sit in the corners in mono: a coloured status top-left, the
/// aspect ratio top-right, and a render progress bar along the bottom.
class EcCreditFrame extends StatelessWidget {
  final Widget child;
  final double? height;
  final double radius;
  final String? status;
  final Color? statusColor;
  final String? corner;
  final double? progress;
  final String? footnote;

  const EcCreditFrame({
    super.key,
    required this.child,
    this.height,
    this.radius = EcRadius.inner,
    this.status,
    this.statusColor,
    this.corner,
    this.progress,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final overlay = context.type.pill.copyWith(letterSpacing: 1.1);
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: p.monitor, borderRadius: BorderRadius.circular(radius)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: child),
          if (status != null)
            Positioned(
              left: 12,
              top: 11,
              child: Text('● ${caps(status!)}', style: overlay.copyWith(color: statusColor ?? p.accentOnBlack)),
            ),
          if (corner != null)
            Positioned(
              right: 12,
              top: 11,
              child: Text(corner!, style: overlay.copyWith(color: Colors.white.withValues(alpha: 0.6))),
            ),
          if (footnote != null)
            Positioned(
              left: 14,
              bottom: 12,
              child: Text(caps(footnote!), style: overlay.copyWith(color: Colors.white.withValues(alpha: 0.62))),
            ),
          if (progress != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.14),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress!.clamp(0, 1),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF0C8CE9), Color(0xFF7B6CFF)]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One credit card as it would render on the roll: a small tracked header
/// over one or more names, Archivo Narrow, upper case, white on black.
class CreditCard extends StatelessWidget {
  final String header;
  final List<String> names;
  final double nameSize;

  const CreditCard({super.key, required this.header, required this.names, this.nameSize = 17});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header.isNotEmpty) ...[
          Text(caps(header), textAlign: TextAlign.center, style: creditHeaderStyle(nameSize)),
          SizedBox(height: nameSize * 0.55),
        ],
        for (var i = 0; i < names.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : nameSize * 0.35),
            child: Text(
              caps(names[i]),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: creditNameStyle(nameSize).copyWith(
                color: Colors.white.withValues(alpha: i == 0 ? 0.93 : 0.72),
              ),
            ),
          ),
      ],
    );
  }
}

/// A cast pair as rendered: role right-aligned and dimmer, name left-aligned.
class CreditPair extends StatelessWidget {
  final String role;
  final String name;
  final double size;
  final double width;

  const CreditPair({super.key, required this.role, required this.name, this.size = 11, this.width = 250});

  @override
  Widget build(BuildContext context) {
    final style = creditNameStyle(size);
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(
            child: Text(caps(role),
                textAlign: TextAlign.right, style: style.copyWith(color: Colors.white.withValues(alpha: 0.65))),
          ),
          SizedBox(width: size * 1.3),
          Expanded(child: Text(caps(name), style: style)),
        ],
      ),
    );
  }
}

/// Header line of a credit card: small, dim, widely tracked.
TextStyle creditHeaderStyle(double nameSize) => GoogleFonts.archivoNarrow(
      fontSize: (nameSize * 0.55).clamp(8, 40),
      letterSpacing: nameSize * 0.55 * 0.32,
      color: Colors.white.withValues(alpha: 0.55),
    );

/// A name on a credit card.
TextStyle creditNameStyle(double size) => GoogleFonts.archivoNarrow(
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: size * 0.13,
      color: Colors.white,
    );

/// A 64 × 48 black thumbnail with two credit "lines" — the shorthand for a
/// project or template in lists and sheet headers. [portrait] draws a
/// vertical frame inside it, for 9:16 templates.
class EcFrameThumb extends StatelessWidget {
  final bool portrait;
  final bool wideFirst;

  const EcFrameThumb({super.key, this.portrait = false, this.wideFirst = true});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double a) => Container(width: w, height: 2, color: Colors.white.withValues(alpha: a));
    final lines = [bar(wideFirst ? 30 : 24, 0.85), const SizedBox(height: 4), bar(wideFirst ? 20 : 32, 0.45)];
    return Container(
      width: 64,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: context.palette.monitor, borderRadius: BorderRadius.circular(EcRadius.tile)),
      child: portrait
          ? Container(
              width: 22,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [bar(12, 0.85), const SizedBox(height: 3), bar(12, 0.5)],
              ),
            )
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: lines),
    );
  }
}
