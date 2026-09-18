import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/ec_sheet.dart';
import '../../../project/controllers/project_controller.dart';
import '../../../../domain/models/project_settings.dart';

/// 2D flat roll (the professional default) vs. 3D perspective crawl —
/// making explicit in the UI that 2D is the standard and 3D is a
/// stylistic choice (§8 of the brief).
class LookSheet extends ConsumerWidget {
  const LookSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(projectControllerProvider.select((s) => s.settings));
    final controller = ref.read(projectControllerProvider.notifier);

    return EcSheet(
      title: 'Monitor look',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _lookCard(
                  selected: settings.look == RollLook.flat2d,
                  title: '2D flat roll',
                  subtitle: 'Professional default. What a conform expects.',
                  preview: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _bar(.54, .8),
                      const SizedBox(height: 5),
                      _bar(.38, .5),
                      const SizedBox(height: 5),
                      _bar(.46, .5),
                    ],
                  ),
                  onTap: () => controller.setLook(RollLook.flat2d),
                ),
              ),
              const SizedBox(width: EcSpace.s3),
              Expanded(
                child: _lookCard(
                  selected: settings.look == RollLook.crawl3d,
                  title: '3D perspective crawl',
                  subtitle: 'A stylistic choice, not the standard.',
                  preview: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _bar(.22, .3),
                      const SizedBox(height: 5),
                      _bar(.4, .55),
                      const SizedBox(height: 5),
                      _bar(.62, .85),
                      const SizedBox(height: 6),
                    ],
                  ),
                  onTap: () => controller.setLook(RollLook.crawl3d),
                ),
              ),
            ],
          ),
          if (settings.look == RollLook.crawl3d) ...[
            const SizedBox(height: EcSpace.s4),
            _slider('Tilt angle', '${settings.tilt.round()}°', settings.tilt, 8, 55, (v) => controller.setTilt(v)),
            const SizedBox(height: EcSpace.s4),
            _slider('Vanishing distance', '${settings.vanishingDistance.round()}%', settings.vanishingDistance, 20, 140, (v) => controller.setVanishingDistance(v)),
          ],
        ],
      ),
    );
  }

  Widget _bar(double width, double opacity) {
    return FractionallySizedBox(
      widthFactor: width,
      child: Container(height: 3, color: Colors.white.withValues(alpha: opacity)),
    );
  }

  Widget _lookCard({required bool selected, required String title, required String subtitle, required Widget preview, required VoidCallback onTap}) {
    return Material(
      color: selected ? EcColors.accentWash : EcColors.surfaceRaised,
      borderRadius: BorderRadius.circular(EcRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(EcRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(EcSpace.s3),
          decoration: BoxDecoration(border: Border.all(color: selected ? EcColors.accentPrimary : EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.lg)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 54, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(EcRadius.sm)), padding: const EdgeInsets.symmetric(horizontal: 10), child: preview),
              const SizedBox(height: EcSpace.s2),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: EcColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: EcColors.textSecondary, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider(String label, String valueLabel, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: EcColors.textSecondary)),
            Text(valueLabel, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 12, color: EcColors.accentPrimary)),
          ],
        ),
        Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
