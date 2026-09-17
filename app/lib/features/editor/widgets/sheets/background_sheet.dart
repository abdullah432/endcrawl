import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/ec_sheet.dart';
import '../../../monitor/widgets/monitor_background.dart';
import '../../../project/controllers/project_controller.dart';
import '../../../project/models/project_settings.dart';

const _kBgOptions = [
  (MonitorBackground.black, 'Pure black', 'Broadcast default'),
  (MonitorBackground.alpha, 'Alpha', 'Drops onto a timeline'),
  (MonitorBackground.green, 'Green', 'Key it yourself'),
  (MonitorBackground.custom, 'Colour', 'Brand ground'),
  (MonitorBackground.underlay, 'Footage', 'Check contrast'),
];

/// Backgrounds (§8): pure black, transparent/alpha, green screen, custom
/// color, and video-underlay preview — plus the safe-area guide toggle.
class BackgroundSheet extends ConsumerWidget {
  const BackgroundSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(projectControllerProvider.select((s) => s.settings));
    final controller = ref.read(projectControllerProvider.notifier);

    return EcSheet(
      title: 'Background',
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: EcSpace.s2,
            crossAxisSpacing: EcSpace.s2,
            childAspectRatio: 1.7,
            children: [
              for (final o in _kBgOptions)
                Material(
                  color: settings.background == o.$1 ? EcColors.accentWash : EcColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(EcRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(EcRadius.md),
                    onTap: () => controller.setBackground(o.$1),
                    child: Container(
                      padding: const EdgeInsets.all(EcSpace.s3),
                      decoration: BoxDecoration(border: Border.all(color: settings.background == o.$1 ? EcColors.accentPrimary : EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.md)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(EcRadius.sm),
                            child: SizedBox(height: 26, width: double.infinity, child: MonitorBackgroundLayer(background: o.$1)),
                          ),
                          const SizedBox(height: EcSpace.s2),
                          Text(o.$2, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: EcColors.textPrimary)),
                          Text(o.$3, style: const TextStyle(fontSize: 10.5, color: EcColors.textTertiary)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: EcSpace.s4),
          Container(
            padding: const EdgeInsets.all(EcSpace.s3),
            decoration: BoxDecoration(color: EcColors.surfaceRaised, border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.md)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Safe-area guides', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: EcColors.textPrimary)),
                    Text('Title 80% · action 90%', style: TextStyle(fontSize: 11, color: EcColors.textTertiary)),
                  ],
                ),
                Switch(
                  value: settings.safeGuides,
                  onChanged: (_) => controller.toggleSafeGuides(),
                  activeThumbColor: Colors.white,
                  activeTrackColor: EcColors.accentPrimary,
                  inactiveTrackColor: EcColors.surfaceHi,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
