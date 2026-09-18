import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/models/credit_face.dart';

/// A credit roll, scrolling behind the welcome screen.
///
/// This is the product demonstrating itself: no copy explains a rolling
/// credit sequence as well as a rolling credit sequence does, and it costs
/// the user nothing to watch — they can sign in straight over the top of it.
///
/// It is a purpose-built loop rather than the real monitor. The monitor is
/// driven by `ProjectController` and needs measured block geometry and a
/// playback clock; wiring the welcome screen to all of that would couple the
/// first screen in the app to the editor's entire state graph in exchange
/// for a backdrop nobody reads. The typography comes from the same
/// [CreditFace] the real roll uses, so it still looks like the product.
class RollHero extends StatefulWidget {
  const RollHero({super.key});

  @override
  State<RollHero> createState() => _RollHeroState();
}

class _RollHeroState extends State<RollHero> with SingleTickerProviderStateMixin {
  static const _cycle = Duration(seconds: 42);

  late final AnimationController _controller = AnimationController(vsync: this, duration: _cycle);

  /// Whether the roll is currently allowed to move. Kept in sync with the
  /// platform's reduce-motion setting in [didChangeDependencies].
  bool _animating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Honour the system reduce-motion setting: a large, continuously moving
    // field is exactly what that preference exists to suppress. With motion
    // off the roll still renders — it simply holds a frame.
    final allowed = !MediaQuery.disableAnimationsOf(context);
    if (allowed == _animating) return;

    _animating = allowed;
    if (allowed) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0.18;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Two copies chase each other so the loop never shows a
                  // seam: as the first scrolls off the top, the second is
                  // already a full height behind it.
                  final offset = -_controller.value * height * 2;
                  return Stack(
                    children: [
                      Positioned(top: offset + height, left: 0, right: 0, child: child!),
                      Positioned(top: offset + height * 3, left: 0, right: 0, child: child),
                    ],
                  );
                },
                child: const _HeroCredits(),
              ),
              // Legibility over spectacle: the roll is a texture, and the
              // sign-in controls on top of it have to stay readable.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      EcColors.surfaceCanvas,
                      Color(0x990B0D10),
                      Color(0xCC0B0D10),
                      EcColors.surfaceCanvas,
                    ],
                    stops: [0, 0.22, 0.62, 1],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The roll's content: a short, real-looking credit sequence.
class _HeroCredits extends StatelessWidget {
  const _HeroCredits();

  static const _sequence = <(String, List<String>)>[
    ('DIRECTED BY', ['Mara Oyelaran']),
    ('WRITTEN BY', ['Mara Oyelaran', 'Tobias Renn']),
    ('PRODUCED BY', ['Ines Kovač', 'Daniel Whitfield']),
    ('DIRECTOR OF PHOTOGRAPHY', ['Aurélie Banks']),
    ('EDITED BY', ['Sam Oduya']),
    ('PRODUCTION DESIGNER', ['Noor Haddad']),
    ('MUSIC BY', ['Felix Arinze']),
    ('CASTING BY', ['Priya Raghunathan']),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'THE LONG WAY DOWN',
          textAlign: TextAlign.center,
          style: CreditFace.condensed.textStyle(
            size: 34,
            weight: FontWeight.w600,
            color: Colors.white.withValues(alpha: .9),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: EcSpace.s7),
        for (final (header, names) in _sequence) ...[
          Text(
            header,
            textAlign: TextAlign.center,
            style: CreditFace.condensed.textStyle(
              size: 10,
              color: Colors.white.withValues(alpha: .45),
              letterSpacing: 2.4,
            ),
          ),
          const SizedBox(height: EcSpace.s1),
          for (final name in names)
            Text(
              name,
              textAlign: TextAlign.center,
              style: CreditFace.condensed.textStyle(
                size: 15,
                weight: FontWeight.w500,
                color: Colors.white.withValues(alpha: .72),
              ),
            ),
          const SizedBox(height: EcSpace.s6),
        ],
      ],
    );
  }
}
