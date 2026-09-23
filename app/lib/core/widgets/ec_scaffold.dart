import 'package:flutter/material.dart';

import '../theme/ec_palette.dart';
import '../theme/theme_context.dart';

/// The screen ground: warm off-white with a cool bloom top-left and a warm
/// one to the right, as in the design's `--ec-screen`.
///
/// Painted once behind every screen. The "glass" cards are translucent white
/// over this, which is what makes them read as frosted — there is no
/// `BackdropFilter` in lists, because the ground is static and a blur over
/// it would cost a layer per card for no visible difference.
class EcGround extends StatelessWidget {
  final Widget child;

  const EcGround({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GroundPainter(context.palette),
      child: child,
    );
  }
}

class _GroundPainter extends CustomPainter {
  final EcPalette palette;
  _GroundPainter(this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.ground);
    // radial-gradient(85% 40% at 0% -4%, cool, transparent 70%)
    _bloom(canvas, Offset(0, -0.04 * size.height), Size(0.85 * size.width, 0.40 * size.height), palette.bloomCool);
    // radial-gradient(60% 32% at 104% 34%, warm, transparent 70%)
    _bloom(canvas, Offset(1.04 * size.width, 0.34 * size.height), Size(0.60 * size.width, 0.32 * size.height), palette.bloomWarm);
  }

  /// An elliptical radial gradient: a circular one drawn in a scaled space.
  void _bloom(Canvas canvas, Offset centre, Size radii, Color color) {
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(1, radii.height / radii.width);
    final r = radii.width;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
        stops: const [0, 0.7],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    canvas.drawCircle(Offset.zero, r, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GroundPainter old) => old.palette != palette;
}

/// A screen: ground, safe area, optional [EcTopBar], and a body.
///
/// [scrollable] wraps the body in a scroll view with the design's 20 px
/// gutter, which is what almost every form-like screen wants; screens with
/// their own lists pass `false` and lay out the body themselves.
class EcScaffold extends StatelessWidget {
  final EcTopBar? topBar;
  final Widget body;
  final bool scrollable;
  final EdgeInsets padding;
  final Widget? bottom;

  const EcScaffold({
    super.key,
    this.topBar,
    required this.body,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 30),
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: EcGround(
        child: SafeArea(
          child: Column(
            children: [
              ?topBar,
              Expanded(
                child: scrollable
                    ? LayoutBuilder(
                        // minHeight lets a body push content to the bottom
                        // with a Spacer, while still scrolling when the
                        // keyboard or a large text scale needs it.
                        builder: (context, constraints) => SingleChildScrollView(
                          padding: padding,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight - padding.vertical),
                            child: IntrinsicHeight(child: body),
                          ),
                        ),
                      )
                    : Padding(padding: padding, child: body),
              ),
              ?bottom,
            ],
          ),
        ),
      ),
    );
  }
}

/// The 52 px bar above a screen: a glass back button, an optional centred
/// serif title, and an optional trailing widget (a "Save" link, "1 / 2").
class EcTopBar extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool showBack;

  const EcTopBar({super.key, this.title, this.trailing, this.onBack, this.showBack = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Align(
                alignment: Alignment.centerLeft,
                child: showBack
                    ? EcCircleButton.glass(
                        icon: Icons.chevron_left_rounded,
                        tooltip: 'Back',
                        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                      )
                    : null,
              ),
            ),
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : Text(title!, textAlign: TextAlign.center, style: context.type.barTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: 64,
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CircleStyle { glass, tint, surface }

/// A round icon button — the glass back button, the tint close button on
/// sheets, the "···" on cards, the steppers' − and +.
class EcCircleButton extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final _CircleStyle _style;

  const EcCircleButton.glass({super.key, this.icon, this.child, this.onPressed, this.tooltip, this.size = 40})
      : _style = _CircleStyle.glass;

  const EcCircleButton.tint({super.key, this.icon, this.child, this.onPressed, this.tooltip, this.size = 40})
      : _style = _CircleStyle.tint;

  const EcCircleButton.surface({super.key, this.icon, this.child, this.onPressed, this.tooltip, this.size = 44})
      : _style = _CircleStyle.surface;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (fill, border) = switch (_style) {
      _CircleStyle.glass => (p.glass, Border.all(color: p.glassEdge)),
      _CircleStyle.tint => (p.tint, null),
      _CircleStyle.surface => (p.surface, Border.all(color: p.line)),
    };
    final button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: border),
          child: Center(
            child: child ?? Icon(icon, size: size * 0.5, color: onPressed == null ? p.faint : p.ink2),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
