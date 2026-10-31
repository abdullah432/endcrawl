import 'package:flutter/material.dart';

import '../../../core/layout/layout_class.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_logo.dart';
import '../../home/tablet_layout.dart';
import '../../onboarding/widgets/roll_hero.dart';

enum AuthHero {
  /// Credits rolling on the monitor — sign in, reset password (T0.1, D1).
  roll,

  /// What the free plan includes, so nobody signs up expecting a trial
  /// (T0.2).
  free,
}

/// T0.1 / T0.2 / D1 — on a tablet or desktop browser, the monitor is the
/// hero and the form sits beside it. On the phone [child] shows as it is.
class AuthSplit extends StatelessWidget {
  final AuthHero hero;
  final Widget child;

  const AuthSplit({super.key, required this.hero, required this.child});

  @override
  Widget build(BuildContext context) {
    final layout = context.screenClass;
    // T0.1 / P0.1: on a tablet the form is 520 wide beside the monitor, or
    // sits under it when the monitor becomes a band across the top.
    switch (context.tabletLayout) {
      case TabletLayout.landscape:
        return Material(
          color: context.palette.sheet,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _HeroPanel(hero: hero, desktop: false)),
              SizedBox(width: 520, child: child),
            ],
          ),
        );
      case TabletLayout.portrait:
        return Material(
          color: context.palette.sheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 470 + MediaQuery.paddingOf(context).top,
                child: _HeroPanel(hero: hero, desktop: false, band: true),
              ),
              Expanded(child: child),
            ],
          ),
        );
      case null:
        break;
    }
    if (!layout.isWide) return child;
    final width = MediaQuery.sizeOf(context).width;
    final formWidth = (width * (layout == LayoutClass.expanded ? .36 : .44)).clamp(440.0, 560.0);
    return Material(
      color: context.palette.sheet,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _HeroPanel(hero: hero, desktop: layout == LayoutClass.expanded),
          ),
          // Clipped: the form's ground paints its colour blooms past its
          // own edges, which would tint the black panel.
          SizedBox(
            width: formWidth,
            child: ClipRect(child: child),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final AuthHero hero;
  final bool desktop;

  /// P0.1: a band across the top of a portrait tablet, lit at two corners.
  final bool band;
  const _HeroPanel({required this.hero, required this.desktop, this.band = false});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final headline = t.displayXL.copyWith(
      fontSize: desktop || (context.isTablet && !band) ? (desktop ? 46 : 48) : 42,
      height: 1.05,
      color: Colors.white,
    );
    final mono = t.mono.copyWith(fontSize: 10, letterSpacing: 2, color: Colors.white.withValues(alpha: .55));
    final line = t.bodyS.copyWith(fontSize: 13.5, color: Colors.white.withValues(alpha: .85));

    final tablet = context.isTablet;
    return ColoredBox(
      color: Colors.black,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black,
          gradient: band
              ? const RadialGradient(
                  center: Alignment(-1, -1),
                  radius: 1.1,
                  colors: [Color(0x660C8CE9), Color(0x000C8CE9)],
                  stops: [0, .55],
                )
              : null,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: band
                ? const RadialGradient(
                    center: Alignment(1.05, 1.1),
                    radius: .9,
                    colors: [Color(0x556A5AF5), Color(0x006A5AF5)],
                    stops: [0, .6],
                  )
                : null,
          ),
          child: SafeArea(
            right: false,
            bottom: !band,
            child: Padding(
              padding: tablet ? const EdgeInsets.fromLTRB(44, 40, 44, 40) : const EdgeInsets.fromLTRB(40, 36, 40, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EcLogo(size: 12, color: Colors.white),
                  Expanded(
                    child: hero == AuthHero.roll
                        ? ExcludeSemantics(
                            child: Center(child: RollHero(height: band ? 240 : 300)),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (hero == AuthHero.roll) ...[
                    Text('24 FPS · 4 PX/FRAME', style: mono),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'End credits that roll '),
                          TextSpan(
                            text: 'like the real thing.',
                            style: headline.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                      style: headline,
                    ),
                    if (desktop) ...[
                      const SizedBox(height: 14),
                      Text('Build the crawl on your phone, finish it at a desk, export it for the edit.', style: line),
                    ],
                  ] else ...[
                    Text('WHAT YOU GET ON FREE', style: mono),
                    const SizedBox(height: 14),
                    for (final item in const [
                      'Every block, timing and look tool.',
                      'Two projects, kept for as long as you like.',
                      'H.264 and HEVC up to 1080p, no watermark.',
                    ]) ...[Text(item, style: line), const SizedBox(height: 10)],
                    const SizedBox(height: 14),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Your first roll is '),
                          TextSpan(
                            text: 'a minute away.',
                            style: headline.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                      style: headline,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The form side of a tablet's sign-in screens (T0.1, T0.2, P0.1): on the
/// sheet colour, centred in its 520 column in landscape; in portrait a
/// 640-wide column under the monitor band, with [footer] at the foot.
class TabletAuthForm extends StatelessWidget {
  final List<Widget> children;
  final Widget? footer;

  const TabletAuthForm({super.key, required this.children, this.footer});

  @override
  Widget build(BuildContext context) {
    final portrait = context.tabletLayout == TabletLayout.portrait;
    return Scaffold(
      backgroundColor: context.palette.sheet,
      body: SafeArea(
        top: !portrait,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = portrait
                ? const EdgeInsets.fromLTRB(32, 40, 32, 40)
                : const EdgeInsets.symmetric(horizontal: 52, vertical: 32);
            return SingleChildScrollView(
              padding: padding,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: portrait ? 640 : double.infinity,
                    minHeight: constraints.maxHeight - padding.vertical,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: portrait ? MainAxisAlignment.start : MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...children,
                        if (footer != null) ...[if (portrait) const Spacer() else const SizedBox(height: 18), footer!],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// "OR WITH EMAIL" between the sign-in buttons and the form (T0.1); in
/// lower case on a portrait tablet (P0.1).
class AuthEmailDivider extends StatelessWidget {
  const AuthEmailDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final portrait = context.tabletLayout == TabletLayout.portrait;
    final line = Expanded(child: Container(height: 1, color: p.line));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            portrait ? 'or with email' : 'OR WITH EMAIL',
            style: portrait
                ? t.bodyS.copyWith(fontSize: 12, color: p.muted)
                : t.mono.copyWith(fontSize: 10.5, letterSpacing: 10.5 * .12, color: p.faint),
          ),
        ),
        line,
      ],
    );
  }
}
