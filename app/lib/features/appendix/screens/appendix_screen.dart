import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

const _kColorTokens = [
  ('--bg-stage', EcColors.bgStage),
  ('--surface-canvas', EcColors.surfaceCanvas),
  ('--surface-sunken', EcColors.surfaceSunken),
  ('--surface-raised', EcColors.surfaceRaised),
  ('--surface-overlay', EcColors.surfaceOverlay),
  ('--surface-hi', EcColors.surfaceHi),
  ('--border-hairline', EcColors.borderHairline),
  ('--border-strong', EcColors.borderStrong),
  ('--accent-primary', EcColors.accentPrimary),
  ('--accent-dim', EcColors.accentDim),
  ('--warn', EcColors.warn),
  ('--text-primary', EcColors.textPrimary),
  ('--text-secondary', EcColors.textSecondary),
  ('--text-tertiary', EcColors.textTertiary),
];

const _kSpaceTokens = [
  ('--space-1', 4.0), ('--space-2', 8.0), ('--space-3', 12.0), ('--space-4', 16.0),
  ('--space-5', 20.0), ('--space-6', 24.0), ('--space-7', 32.0), ('--space-8', 40.0),
];

const _kRadiusTokens = [('sm', 6.0), ('md', 10.0), ('lg', 14.0), ('xl', 22.0), ('full', 26.0)];

const _kMotionTokens = [
  ('--dur-fast 150ms', 'State flips: selection, mute, leader style.'),
  ('--dur-base 200ms', 'Card reorder parting, toggle knobs.'),
  ('--dur-slow 250ms', 'Sheet rise, format reflow.'),
  ('haptic 8ms', 'Block lifts under a long-press.'),
  ('haptic 12ms', 'Block drops into its new slot.'),
  ('haptic 6ms', 'Fast-entry row committed; scrub crosses a card boundary.'),
];

const _kEdgeCases = [
  ('Empty project', 'Template chooser, not a blank canvas — five real starting points, each with the card order already right.'),
  ('One block only', 'Roll still renders; head and tail black keep it legal. Status line shows the true runtime.'),
  ('400-name cast', 'Row list virtualises, and an A–Z rail on the right jumps by first character of the left column.'),
  ('Name too long for its column', 'Rule: wrap with a hanging indent inside the column — never shrink, never overflow the gutter.'),
  ('Unreadable duration', 'Blocked from silently rendering: the warning names the dwell time, the 3.0s floor, and offers the two nearest clean runtimes.'),
  ('Missing font file', 'Card shows a FONT badge and the missing filename. The roll falls back to the project face.'),
  ('Export failure', 'Stated cause and the resolution fix; the cached portion resumes rather than restarting.'),
  ('Offline · crash recovery', 'Everything renders on-device, so offline is a status glyph, not a blocker. Autosave every edit.'),
];

/// A component/token appendix — the design system reference this app is
/// built from (§11 of the brief): color ramp, type scale, spacing,
/// radius, motion/haptics, and the stated edge-case rules.
class AppendixScreen extends StatelessWidget {
  const AppendixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcColors.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: EcColors.surfaceCanvas,
        foregroundColor: EcColors.textPrimary,
        title: const Text('Tokens & components', style: TextStyle(fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(EcSpace.s4),
        children: [
          _section('Colour ramp'),
          Wrap(
            spacing: EcSpace.s2,
            runSpacing: EcSpace.s2,
            children: [
              for (final c in _kColorTokens)
                Container(
                  width: 160,
                  padding: const EdgeInsets.all(EcSpace.s2),
                  decoration: BoxDecoration(color: EcColors.surfaceRaised, border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.md)),
                  child: Row(
                    children: [
                      Container(width: 34, height: 34, decoration: BoxDecoration(color: c.$2, border: Border.all(color: EcColors.borderStrong), borderRadius: BorderRadius.circular(EcRadius.sm))),
                      const SizedBox(width: EcSpace.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.$1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 10.5, color: EcColors.textPrimary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: EcSpace.s6),
          _section('Credit faces — shipped list'),
          for (final f in CreditFace.values)
            Container(
              margin: const EdgeInsets.only(bottom: EcSpace.s2),
              padding: const EdgeInsets.symmetric(horizontal: EcSpace.s4, vertical: EcSpace.s3),
              decoration: BoxDecoration(color: Colors.black, border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.label, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 9.5, color: EcColors.textTertiary)),
                  const SizedBox(height: EcSpace.s2),
                  Text('DIRECTOR OF PHOTOGRAPHY', style: f.textStyle(size: 20)),
                ],
              ),
            ),
          const SizedBox(height: EcSpace.s6),
          _section('Spacing scale'),
          for (final s in _kSpaceTokens)
            Padding(
              padding: const EdgeInsets.only(bottom: EcSpace.s2),
              child: Row(
                children: [
                  SizedBox(width: 100, child: Text(s.$1, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 9.5, color: EcColors.textTertiary))),
                  Container(width: s.$2, height: 8, decoration: BoxDecoration(color: EcColors.accentPrimary, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: EcSpace.s2),
                  Text('${s.$2.round()}px', style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 9.5, color: EcColors.textSecondary)),
                ],
              ),
            ),
          const SizedBox(height: EcSpace.s6),
          _section('Radius'),
          Wrap(
            spacing: EcSpace.s3,
            runSpacing: EcSpace.s3,
            children: [
              for (final r in _kRadiusTokens)
                Column(
                  children: [
                    Container(width: 52, height: 52, decoration: BoxDecoration(color: EcColors.surfaceRaised, border: Border.all(color: EcColors.borderStrong), borderRadius: BorderRadius.circular(r.$2.clamp(0, 26)))),
                    const SizedBox(height: 6),
                    Text(r.$1, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 9.5, color: EcColors.textTertiary)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: EcSpace.s6),
          _section('Motion & haptics'),
          for (final m in _kMotionTokens)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 118, child: Text(m.$1, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 10, color: EcColors.accentPrimary))),
                  Expanded(child: Text(m.$2, style: const TextStyle(fontSize: 11.5, color: EcColors.textSecondary, height: 1.35))),
                ],
              ),
            ),
          const SizedBox(height: EcSpace.s6),
          _section('Edge cases — the rules, stated'),
          for (final x in _kEdgeCases)
            Container(
              margin: const EdgeInsets.only(bottom: EcSpace.s3),
              padding: const EdgeInsets.all(EcSpace.s3),
              decoration: BoxDecoration(color: EcColors.surfaceRaised, border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(x.$1, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: EcColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(x.$2, style: const TextStyle(fontSize: 11.5, color: EcColors.textSecondary, height: 1.4)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EcSpace.s3),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 2, color: EcColors.textTertiary)),
    );
  }
}
