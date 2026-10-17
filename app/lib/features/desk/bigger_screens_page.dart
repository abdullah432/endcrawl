import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap.dart';
import '../../core/config/app_links.dart';
import '../../core/theme/ec_type.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/ec_button.dart';
import '../../core/widgets/ec_headline.dart';
import '../../core/widgets/ec_scaffold.dart';
import '../../core/widgets/ec_toast.dart';

/// 1.8c — the web app opened at phone width, from Pro's link or Free's
/// "Preview on the web".
///
/// LastReel on the web is the desk: rather than squeeze the editor, it
/// names the fix (use a computer) and does the work — one tap emails the
/// link to the person's own inbox, or copies it. Widening the window past
/// the phone layout swaps in the app straight away, with no reload.
class BiggerScreensPage extends ConsumerWidget {
  const BiggerScreensPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final email = ref.watch(authStateProvider).value?.email ?? '';
    final links = ref.read(externalLinksProvider);
    final appListing = AppLinks.appListing;

    Future<void> emailLink() async {
      final opened = await links.composeEmail(
        email,
        subject: 'LastReel on your computer',
        body: 'Open this on your computer and sign in with $email — your projects are already there:\n\n'
            '${AppLinks.webApp}',
      );
      if (!opened && context.mounted) showEcToast(context, 'No email app found. Copy the link instead.');
    }

    Future<void> copyLink() async {
      await Clipboard.setData(ClipboardData(text: AppLinks.webApp.toString()));
      if (context.mounted) showEcToast(context, 'Link copied. Open it on your computer.');
    }

    return Scaffold(
      body: EcGround(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 58),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Screens(),
                      const SizedBox(height: 26),
                      Text(caps('LastReel on the web'), style: t.eyebrow.copyWith(color: p.accent)),
                      const SizedBox(height: 8),
                      Semantics(
                        header: true,
                        child: EcHeadline(
                          'Made for ',
                          emphasis: 'bigger screens.',
                          style: t.displayL.copyWith(fontSize: 40, height: 1),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'LastReel Desktop only works at desktop size. Open this link on your computer '
                        'and your projects will be waiting.',
                        style: t.bodyL.copyWith(fontSize: 15, color: p.ink2, height: 1.5),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: p.line),
                          boxShadow: p.rowShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Send it to your computer', style: t.titleS.copyWith(fontSize: 13)),
                            const SizedBox(height: 10),
                            EcButton(
                              label: 'Email me this link',
                              leading: Icon(Icons.send_outlined, size: 17, color: p.onInk),
                              onPressed: email.isEmpty ? null : emailLink,
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Sends to $email',
                                textAlign: TextAlign.center,
                                style: t.label.copyWith(fontWeight: FontWeight.w400, color: p.muted),
                              ),
                            ],
                            const SizedBox(height: 10),
                            EcButton.secondary(
                              label: 'Copy link',
                              height: 50,
                              leading: Icon(Icons.link_rounded, size: 16, color: p.ink),
                              onPressed: copyLink,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (appListing != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Want to keep going on this phone?',
                          textAlign: TextAlign.center,
                          style: t.bodyS.copyWith(color: p.muted),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: EcButton.text(
                            label: 'Open the LastReel app',
                            trailing: Icon(Icons.arrow_forward_rounded, size: 16, color: p.accent),
                            onPressed: () => links.openUrl(appListing),
                          ),
                        ),
                      ],
                    ],
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

/// A laptop in the accent colour beside a faint phone.
class _Screens extends StatelessWidget {
  const _Screens();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CustomPaint(size: const Size(92, 64), painter: _LaptopPainter(p.accent)),
          const SizedBox(width: 10),
          CustomPaint(size: const Size(26, 44), painter: _PhonePainter(p.faint)),
        ],
      ),
    );
  }
}

Paint _stroke(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class _LaptopPainter extends CustomPainter {
  final Color color;
  const _LaptopPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _stroke(color);
    canvas.drawRRect(RRect.fromLTRBR(12, 4, 80, 48, const Radius.circular(4)), paint);
    canvas.drawPath(
      Path()
        ..moveTo(4, 56)
        ..lineTo(88, 56)
        ..lineTo(82, 48)
        ..lineTo(10, 48)
        ..close(),
      paint,
    );
    canvas.drawLine(const Offset(22, 14), const Offset(38, 14), paint);
    canvas.drawLine(const Offset(22, 22), const Offset(32, 22), paint);
    canvas.drawRect(const Rect.fromLTRB(44, 14, 70, 38), paint);
  }

  @override
  bool shouldRepaint(_LaptopPainter oldDelegate) => oldDelegate.color != color;
}

class _PhonePainter extends CustomPainter {
  final Color color;
  const _PhonePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _stroke(color);
    canvas.drawRRect(RRect.fromLTRBR(2, 2, 24, 42, const Radius.circular(5)), paint);
    canvas.drawLine(const Offset(10, 37), const Offset(16, 37), paint);
  }

  @override
  bool shouldRepaint(_PhonePainter oldDelegate) => oldDelegate.color != color;
}
