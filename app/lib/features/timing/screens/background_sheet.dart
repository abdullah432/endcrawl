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
          for (final row in [_options.sublist(0, 2), _options.sublist(2)]) ...[
            Row(
              children: [
                for (final (i, (bg, label, detail)) in row.indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _BackgroundTile(
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
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
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
    final t = context.type;
    return EcChoiceCard(
      selected: selected,
      onTap: onTap,
      radius: EcRadius.row,
      semanticLabel: '$label, $detail',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BackgroundPreview(background: background),
          const SizedBox(height: 8),
          Text(label, style: t.titleS.copyWith(fontSize: 13)),
          Text(detail, style: t.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

/// A miniature monitor: the background with two credit lines on it, drawn
/// the way the roll draws them — white, inverted to ink on paper.
class BackgroundPreview extends StatelessWidget {
  final MonitorBackground background;
  final double height;

  const BackgroundPreview({super.key, required this.background, this.height = 58});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final shadow = background == MonitorBackground.alpha
        ? const [Shadow(color: Color(0x66000000), blurRadius: 3)]
        : null;
    Widget credits = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('DIRECTED BY',
            style: t.pill.copyWith(fontSize: 6, letterSpacing: 2, color: Colors.white.withValues(alpha: .6), shadows: shadow)),
        const SizedBox(height: 3),
        Text('MAYA OKONKWO',
            style: t.pill.copyWith(fontSize: 9, letterSpacing: 1.6, fontWeight: FontWeight.w600, color: Colors.white, shadows: shadow)),
      ],
    );
    if (background == MonitorBackground.paper) credits = ColorFiltered(colorFilter: kPaperInvert, child: credits);

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: background == MonitorBackground.black ? null : Border.all(color: p.line),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MonitorBackgroundLayer(background: background),
          credits,
          if (background == MonitorBackground.reference) ...[
            Positioned(
              left: 6,
              bottom: 4,
              child: Text('SCENE_042.mov', style: t.mono.copyWith(fontSize: 6.5, color: Colors.white.withValues(alpha: .55))),
            ),
            Positioned(
              right: 5,
              top: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(EcRadius.pill),
                ),
                child: Text('SOON', style: t.pill.copyWith(fontSize: 6.5, color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
