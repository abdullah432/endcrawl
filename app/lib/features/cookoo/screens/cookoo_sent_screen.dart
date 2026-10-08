import 'dart:math' as math;

import '../../../core/services/clarity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../controllers/cookoo_promo_controller.dart';
import '../models/cookoo_content.dart';
import '../widgets/cookoo_style.dart';

/// After "Send my idea": a ticket stub of what was sent and what happens
/// next. The way back to the app comes first, the website second.
class CookooSentScreen extends ConsumerWidget {
  final String name;
  final String email;
  final String idea;
  final CookooNeed need;

  /// The phone was offline; the request is saved and sends on reconnect.
  final bool queued;

  const CookooSentScreen({
    super.key,
    required this.name,
    required this.email,
    required this.idea,
    required this.need,
    this.queued = false,
  });

  static const _steps = [
    'We read it and ask a few questions',
    'Free first chat, by call or message',
    'You get a clear price and plan',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final body = context.cookooUi(15, height: 1.5, color: p.ink2);
    final foot = math.max(28 - MediaQuery.paddingOf(context).bottom, 8.0);

    return EcScaffold(
      scrollable: false,
      padding: EdgeInsets.zero,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 20, bottom: 16),
        child: ClarityMask(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(color: p.ok, shape: BoxShape.circle),
                      child: Icon(Icons.check, size: 34, color: p.onInk),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      header: true,
                      child: Text(
                        'Got it, $name.',
                        textAlign: TextAlign.center,
                        style: context.cookooSerif(38, height: 1),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'We’ll read your idea and reply to '),
                            TextSpan(
                              text: email,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const TextSpan(text: ' within 24 hours.'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: body,
                      ),
                    ),
                    if (queued) ...[
                      const SizedBox(height: 8),
                      Text(
                        'You’re offline. It sends when you’re back online.',
                        textAlign: TextAlign.center,
                        style: context.cookooUi(13, color: p.muted, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Ticket(need: need, idea: idea, steps: _steps),
              ),
            ],
          ),
        ),
      ),
      bottom: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, foot),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CookooInkButton(label: 'Back to LastReel', onPressed: () => Navigator.of(context).pop()),
            const SizedBox(height: 6),
            CookooTextLink(
              label: 'While you wait, see our work',
              onTap: () {
                ref.read(cookooPromoProvider.notifier).siteOpened('sent');
                ref.read(externalLinksProvider).openUrl(AppLinks.cookooCases);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Ticket extends StatelessWidget {
  final CookooNeed need;
  final String idea;
  final List<String> steps;

  const _Ticket({required this.need, required this.idea, required this.steps});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YOUR IDEA · ${need.label.toUpperCase()}', style: context.cookooMono(10, tracking: 2)),
                const SizedBox(height: 8),
                Text(
                  idea,
                  style: context.type.displayM.copyWith(fontSize: 20, height: 1.2, letterSpacing: 0),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _TearLine(notch: p.ground, dash: p.line2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, step) in steps.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('0${i + 1}', style: context.cookooMono(11, tracking: 0)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(step, style: context.cookooUi(14))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The dashed tear with a half-circle notch bitten out of each edge.
class _TearLine extends StatelessWidget {
  final Color notch;
  final Color dash;
  const _TearLine({required this.notch, required this.dash});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1.5,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: CustomPaint(painter: _DashPainter(dash))),
          for (final left in [true, false])
            Positioned(
              left: left ? -11 : null,
              right: left ? null : -11,
              top: -10.25,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: notch, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
