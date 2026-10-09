import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/services/clarity.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../controllers/cookoo_promo_controller.dart';
import '../widgets/cookoo_style.dart';

/// After "Send my idea": who has the idea, when they'll hear back, and the
/// three steps that follow. The way back to the app comes first, the
/// website second.
class CookooSentScreen extends ConsumerWidget {
  final String name;
  final String email;

  /// The phone was offline; the request is saved and sends on reconnect.
  final bool queued;

  const CookooSentScreen({super.key, required this.name, required this.email, this.queued = false});

  static const _steps = [
    'We read your idea and reply by email.',
    'A short call to understand what you need.',
    'A scope and estimate before you commit to a build.',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final foot = math.max(28 - MediaQuery.paddingOf(context).bottom, 8.0);

    return EcScaffold(
      scrollable: false,
      padding: EdgeInsets.zero,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        child: ClarityMask(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: p.inkSurface, shape: BoxShape.circle),
                child: Icon(Icons.check, size: 24, color: p.onInk),
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Got it, '),
                      TextSpan(
                        text: '$name.',
                        style: context.cookooSerif(46, height: 1.05, color: p.accent),
                      ),
                    ],
                  ),
                  style: context.type.displayL.copyWith(fontSize: 46, height: 1.05),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Your idea is with the COOKOO team. We’ll get back to $email within 24 hours '
                'to talk about next steps.',
                style: context.cookooUi(15, height: 1.6, color: p.ink2),
              ),
              if (queued) ...[
                const SizedBox(height: 8),
                Text(
                  'You’re offline. It sends when you’re back online.',
                  style: context.cookooUi(13, color: p.muted, height: 1.4),
                ),
              ],
              const SizedBox(height: 26),
              Divider(height: 1, color: p.line),
              for (final (i, step) in _steps.indexed) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 34,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('0${i + 1}', style: context.cookooMono(11, tracking: 0)),
                        ),
                      ),
                      Expanded(child: Text(step, style: context.cookooUi(14.5, height: 1.35))),
                    ],
                  ),
                ),
                Divider(height: 1, color: p.line),
              ],
            ],
          ),
        ),
      ),
      bottom: Padding(
        padding: EdgeInsets.fromLTRB(22, 12, 22, foot),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Pill(label: 'Back to LastReel', filled: true, onTap: () => Navigator.of(context).pop()),
            const SizedBox(height: 8),
            _Pill(
              label: 'See our work on cookoo.dev',
              icon: Icons.arrow_outward,
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

/// A 46 px pill: solid ink for the way back, outlined white for the site.
class _Pill extends StatelessWidget {
  final String label;
  final bool filled;
  final IconData? icon;
  final VoidCallback onTap;

  const _Pill({required this.label, required this.onTap, this.filled = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = filled ? p.onInk : p.ink;
    return Semantics(
      button: true,
      link: icon != null,
      child: Material(
        color: filled ? p.inkSurface : p.surface,
        shape: StadiumBorder(side: filled ? BorderSide.none : BorderSide(color: p.line2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.cookooUi(15, weight: FontWeight.w700, color: fg),
                  ),
                ),
                if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 15, color: p.muted)],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
