import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_choice_card.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../domain/models/project_settings.dart';
import '../../project/controllers/project_controller.dart';

/// 5.2 — 2D flat roll, labelled the default so the app has an opinion, or a
/// 3D crawl as a style choice. The monitor stays unscrimmed above the sheet
/// so every change shows live.
class LookSheet extends ConsumerWidget {
  const LookSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showEcSheet<void>(context, scrim: false, builder: (_) => const LookSheet());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final settings = ref.watch(projectControllerProvider.select((s) => s.settings));
    final controller = ref.read(projectControllerProvider.notifier);
    final is3d = settings.look == RollLook.crawl3d;

    return EcSheet(
      title: 'Monitor look',
      maxHeightFraction: 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _LookCard(
                    selected: !is3d,
                    title: '2D flat roll',
                    badge: 'Default',
                    detail: 'What a conform expects.',
                    bars: const [(.54, .8, 3.0), (.38, .5, 3.0), (.46, .5, 3.0)],
                    alignEnd: false,
                    onTap: () => controller.setLook(RollLook.flat2d),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LookCard(
                    selected: is3d,
                    title: '3D crawl',
                    detail: 'A style choice, not the standard.',
                    bars: const [(.22, .3, 2.0), (.40, .55, 3.0), (.62, .85, 4.0)],
                    alignEnd: true,
                    onTap: () => controller.setLook(RollLook.crawl3d),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AnimatedOpacity(
            duration: EcMotion.fast,
            opacity: is3d ? 1 : .45,
            child: Column(
              children: [
                _LookSlider(
                  label: 'Tilt angle',
                  value: settings.tilt,
                  display: '${settings.tilt.round()}°',
                  min: 8,
                  max: 55,
                  onChanged: is3d ? controller.setTilt : null,
                ),
                const SizedBox(height: 6),
                _LookSlider(
                  label: 'Vanishing distance',
                  value: settings.vanishingDistance,
                  display: '${settings.vanishingDistance.round()}%',
                  min: 20,
                  max: 140,
                  onChanged: is3d ? controller.setVanishingDistance : null,
                ),
              ],
            ),
          ),
          if (!is3d) ...[
            const SizedBox(height: 8),
            Text('Tilt controls unlock only when 3D is selected.', style: t.caption.copyWith(color: p.muted, height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _LookCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String? badge;
  final String detail;

  /// (width fraction, opacity, thickness) of each preview line.
  final List<(double, double, double)> bars;
  final bool alignEnd;
  final VoidCallback onTap;

  const _LookCard({
    required this.selected,
    required this.title,
    this.badge,
    required this.detail,
    required this.bars,
    required this.alignEnd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return EcChoiceCard(
      selected: selected,
      onTap: onTap,
      semanticLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 64,
            padding: EdgeInsets.only(bottom: alignEnd ? 8 : 0),
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(EcRadius.tile)),
            child: LayoutBuilder(
              builder: (context, c) => Column(
                mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.center,
                children: [
                  for (final (i, (w, o, h)) in bars.indexed) ...[
                    if (i > 0) const SizedBox(height: 5),
                    Container(width: c.maxWidth * w, height: h, color: Colors.white.withValues(alpha: o)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(title, style: t.titleS.copyWith(fontSize: 13.5))),
              if (badge != null) Text(caps(badge!), style: t.pill.copyWith(fontSize: 8.5, color: p.accent)),
            ],
          ),
          const SizedBox(height: 3),
          Text(detail, style: t.caption.copyWith(height: 1.35)),
        ],
      ),
    );
  }
}

class _LookSlider extends StatelessWidget {
  final String label;
  final double value;
  final String display;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;

  const _LookSlider({
    required this.label,
    required this.value,
    required this.display,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: t.bodyS.copyWith(fontSize: 12, color: context.palette.ink))),
            Text(onChanged == null ? '—' : display, style: t.mono.copyWith(fontSize: 12)),
          ],
        ),
        Slider(value: value.clamp(min, max), min: min, max: max, label: display, onChanged: onChanged),
      ],
    );
  }
}
