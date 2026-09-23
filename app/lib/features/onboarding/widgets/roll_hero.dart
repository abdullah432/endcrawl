import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_credit_frame.dart';

/// The welcome screen's monitor: a credit roll scrolling in a black frame.
///
/// The product demonstrating itself — nothing explains a rolling credit
/// sequence as well as one rolling. A purpose-built loop rather than the real
/// monitor, which is driven by `ProjectController` and measured block
/// geometry; wiring the first screen to the editor's state for a backdrop
/// would be a bad trade. It uses the same credit typography, so it still
/// looks exactly like the product.
class RollHero extends StatefulWidget {
  final double height;

  const RollHero({super.key, this.height = 250});

  @override
  State<RollHero> createState() => _RollHeroState();
}

class _RollHeroState extends State<RollHero> with SingleTickerProviderStateMixin {
  /// One pass of the sequence. At the frame's size this is roughly the
  /// "4 px/frame at 24 fps" the footnote claims.
  static const _cycle = Duration(seconds: 18);

  late final AnimationController _controller = AnimationController(vsync: this, duration: _cycle);

  bool _animating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce-motion: a continuously moving field is what that setting
    // exists to suppress. With it on, the roll holds a frame.
    final allowed = !MediaQuery.disableAnimationsOf(context);
    if (allowed == _animating) return;
    _animating = allowed;
    if (allowed) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0.05;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0xB30C6EC8), offset: Offset(0, 30), blurRadius: 60, spreadRadius: -30)],
      ),
      child: EcCreditFrame(
        radius: 22,
        footnote: '24 fps · 4 px/frame',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRect(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      // Two copies a sequence-length apart, so the loop has
                      // no seam: one leaves the top as the other arrives.
                      final travel = _sequenceHeight;
                      final y = h - _controller.value * travel;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(top: y, left: 0, right: 0, child: child!),
                          Positioned(top: y - travel, left: 0, right: 0, child: child),
                        ],
                      );
                    },
                    child: const _HeroCredits(),
                  ),
                ),
                // Black fades top and bottom, as a real monitor's roll enters
                // and leaves the frame.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [p.monitor, p.monitor.withValues(alpha: 0), p.monitor.withValues(alpha: 0), p.monitor],
                        stops: const [0, 0.26, 0.72, 1],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The loop length — the sequence's laid-out height plus its trailing gap.
  static const double _sequenceHeight = 420;
}

class _HeroCredits extends StatelessWidget {
  const _HeroCredits();

  static const _cards = <(String, String)>[
    ('Director of photography', 'Yusuf Karadeniz'),
    ('Editor', 'Bruno Takahashi'),
    ('Original music', 'Hana Bexley'),
  ];

  static const _cast = <(String, String)>[
    ('Renny', 'Sofia Alvarez'),
    ('Marcus', 'Idris Oyelaran'),
    ('Dr. Vance', 'Helen Tsai'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _RollHeroState._sequenceHeight,
      child: Column(
        children: [
          for (final (header, name) in _cards) ...[
            CreditCard(header: header, names: [name], nameSize: 14),
            const SizedBox(height: 20),
          ],
          CreditCard(header: 'Cast', names: const [], nameSize: 14),
          for (final (role, name) in _cast) ...[
            CreditPair(role: role, name: name),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
