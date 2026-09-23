import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_choice_card.dart';
import '../../../core/widgets/ec_settings.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/project_settings.dart';
import '../../monitor/widgets/monitor_background.dart';
import '../../project/controllers/project_controller.dart';

/// 5.3 — what the roll plays over, and the safe-area guides. Transparent
/// here is the same idea as an alpha codec at export.
class BackgroundSheet extends ConsumerWidget {
  const BackgroundSheet({super.key});

  static Future<void> show(BuildContext context) =>
      showEcSheet<void>(context, scrim: false, builder: (_) => const BackgroundSheet());

  static const _options = [
    (MonitorBackground.black, 'Full black', 'Delivery default'),
    (MonitorBackground.alpha, 'Transparent', 'Alpha on export'),
    (MonitorBackground.reference, 'Reference clip', 'Coming soon'),
    (MonitorBackground.paper, 'Paper', 'For print proofs'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(projectControllerProvider.select((s) => s.settings));
    final controller = ref.read(projectControllerProvider.notifier);

    return EcSheet(
      title: 'Background',
      maxHeightFraction: 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (bg, label, detail) in _options)
                _BackgroundTile(
                  background: bg,
                  label: label,
                  detail: detail,
                  selected: settings.background == bg,
                  // A reference clip needs a clip to pick; until import
                  // lands the tile explains rather than doing nothing.
                  onTap: bg == MonitorBackground.reference
                      ? () => showEcToast(context, 'Reference clips are coming soon')
                      : () => controller.setBackground(bg),
                ),
            ],
          ),
          const SizedBox(height: 14),
          EcGroup(children: [
            EcGroupRow.toggle(
              title: 'Safe-area guides',
              subtitle: 'Title 80% · action 90%',
              value: settings.safeGuides,
              onChanged: (_) => controller.toggleSafeGuides(),
            ),
          ]),
        ],
      ),
    );
  }
}

class _BackgroundTile extends StatelessWidget {
  final MonitorBackground background;
  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  const _BackgroundTile({
    required this.background,
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return EcChoiceCard(
      selected: selected,
      onTap: onTap,
      radius: EcRadius.row,
      semanticLabel: '$label, $detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: background == MonitorBackground.black ? null : Border.all(color: p.line),
              ),
              child: MonitorBackgroundLayer(background: background),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: t.titleS.copyWith(fontSize: 13)),
          Text(detail, style: t.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
