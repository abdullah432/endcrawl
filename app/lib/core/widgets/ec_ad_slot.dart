import 'package:flutter/material.dart';

import '../theme/ec_type.dart';
import '../theme/theme_context.dart';
import '../theme/tokens.dart';

/// Where an ad goes on the free plan — "Sponsored · Hide ads" above a quiet
/// row card.
///
/// A placeholder until an ad SDK is wired in: it renders the design's house
/// copy so the layout, spacing and the "Hide ads" path to Pro are real now,
/// and the SDK's native view replaces [_PlaceholderCreative] later without
/// any screen changing. Screens only show it when the entitlement says ads
/// are on, so Pro users never see it.
class EcAdSlot extends StatelessWidget {
  final VoidCallback onHideAds;
  final String label;
  final String hideLabel;
  final String headline;
  final String body;

  const EcAdSlot({
    super.key,
    required this.onHideAds,
    this.label = 'Sponsored',
    this.hideLabel = 'Hide ads',
    this.headline = 'Filmsupply — 60% off first licence',
    this.body = 'Stock footage for indie cuts.',
  });

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(child: Text(caps(label), style: t.section.copyWith(letterSpacing: 1.5))),
              InkWell(
                onTap: onHideAds,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  child: Text(caps(hideLabel), style: t.section.copyWith(letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _PlaceholderCreative(headline: headline, body: body),
      ],
    );
  }
}

class _PlaceholderCreative extends StatelessWidget {
  final String headline;
  final String body;
  const _PlaceholderCreative({required this.headline, required this.body});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(EcRadius.row),
        border: Border.all(color: p.glassEdge),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(EcRadius.tile)),
            child: Text('AD', style: t.pill.copyWith(color: p.muted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: t.body.copyWith(color: p.ink, fontWeight: FontWeight.w500, height: 1.3)),
                const SizedBox(height: 2),
                Text(body, style: t.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
