import 'package:flutter/material.dart';

import '../../../core/layout/layout_class.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_logo.dart';
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
    final layout = context.layoutClass;
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
  const _HeroPanel({required this.hero, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final headline = t.displayXL.copyWith(fontSize: desktop ? 46 : 42, height: 1.05, color: Colors.white);
    final mono = t.mono.copyWith(fontSize: 10, letterSpacing: 2, color: Colors.white.withValues(alpha: .55));
    final line = t.bodyS.copyWith(fontSize: 13.5, color: Colors.white.withValues(alpha: .85));

    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EcLogo(size: 12, color: Colors.white),
              Expanded(
                child: hero == AuthHero.roll
                    ? const ExcludeSemantics(child: Center(child: RollHero(height: 300)))
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
    );
  }
}
