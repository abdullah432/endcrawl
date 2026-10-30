import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../models/cookoo_content.dart';
import 'cookoo_style.dart';

/// T9.2 / T9.3 — the proof beside the form on a tablet: who COOKOO are and
/// three apps they run. Beside the form in landscape, across the top in
/// portrait. Black in every theme, like the monitor.
class CookooProofPanel extends StatelessWidget {
  final bool portrait;
  const CookooProofPanel({super.key, this.portrait = false});

  static const _ground = Color(0xFF0E0F14);

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final dim = Colors.white.withValues(alpha: .6);
    final headline = Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'We build apps people '),
          TextSpan(
            text: 'use and pay for.',
            style: context.cookooSerif(portrait ? 36 : 44, height: 1.05, color: const Color(0xFF7FB6FF)),
          ),
        ],
      ),
      style: context.type.displayL.copyWith(fontSize: portrait ? 36 : 44, height: 1.05, color: white),
    );
    final apps = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (app, line) in cookooTrackRecord)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(app.asset, width: 34, height: 34, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: context.cookooUi(14, weight: FontWeight.w600, color: white),
                      ),
                      Text(line, style: context.cookooUi(12, color: dim)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    final header = Row(
      children: [
        Text('COOKOO', style: context.cookooMono(11, tracking: 2, color: white)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: .25)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('PAID DESIGN & DEVELOPMENT', style: context.cookooMono(9, tracking: 1.2, color: dim)),
        ),
      ],
    );
    final foot = Row(
      children: [
        Expanded(
          child: Text(
            '100+ apps shipped · the team behind LastReel',
            style: context.cookooMono(9.5, tracking: 1, color: dim),
          ),
        ),
        Text(
          'cookoo.dev',
          style: context.cookooUi(12, weight: FontWeight.w600, color: const Color(0xFF7FB6FF)),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_outward, size: 13, color: Color(0xFF7FB6FF)),
      ],
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ground, Color(0xFF151A2E), Color(0xFF241A3A)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(28, portrait ? 26 : 30, 28, portrait ? 22 : 28),
      child: portrait
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: headline),
                    const SizedBox(width: 24),
                    apps,
                  ],
                ),
                const SizedBox(height: 8),
                foot,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, const Spacer(), headline, const SizedBox(height: 28), apps, const Spacer(), foot],
            ),
    );
  }
}

/// The tablet's COOKOO screens (T9.2, T9.3): the proof panel and the page,
/// side by side in landscape, stacked in portrait, on one rounded card.
class CookooTabletFrame extends StatelessWidget {
  final bool portrait;
  final Widget child;
  const CookooTabletFrame({super.key, required this.portrait, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.ground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.sheet,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: p.line),
            ),
            child: portrait
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CookooProofPanel(portrait: true),
                      Expanded(child: child),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(width: 380, child: CookooProofPanel()),
                      Expanded(child: child),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
