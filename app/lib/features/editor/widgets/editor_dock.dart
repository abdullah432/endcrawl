import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_option_sheet.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/credit_block.dart';
import '../../blocks/screens/add_block_sheet.dart';
import '../../paste/screens/paste_sheet.dart';
import '../../project/controllers/project_controller.dart';
import '../controllers/editor_ui_controller.dart';
import 'sheets/duration_sheet.dart';
import 'sheets/export_sheet.dart';
import 'status_line.dart';

/// The four actions, floating over the list as one glass dock (3.1):
/// + Block, Paste, Timing (showing the runtime) and Export.
class EditorDock extends ConsumerWidget {
  const EditorDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final project = ref.watch(projectControllerProvider);
    final healthy = rollHealth(project) == RollHealth.clean;
    final runtime = formatClock(project.runtime.inMilliseconds / 1000);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 66,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.glassEdge),
          ),
          child: Row(
            children: [
              _DockItem(glyph: const Icon(Icons.add_rounded, size: 18), label: 'Block', onTap: () => AddBlockSheet.show(context)),
              _DockItem(glyph: const Icon(Icons.keyboard_tab_rounded, size: 16), label: 'Paste', onTap: () => PasteSheet.show(context)),
              _DockItem(
                glyph: Text(runtime, style: context.type.mono.copyWith(fontSize: 11, color: healthy ? p.ink : p.warn)),
                label: 'Timing',
                warn: !healthy,
                onTap: () => showEcSheet<void>(context, builder: (_) => const DurationSheet()),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 14,
                child: Material(
                  type: MaterialType.transparency,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    decoration: BoxDecoration(gradient: p.primary, boxShadow: p.primaryShadow),
                    child: InkWell(
                      onTap: () => showEcSheet<void>(context, builder: (_) => const ExportSheet()),
                      child: Center(child: Text('Export', style: context.type.button.copyWith(fontSize: 14, color: p.onInk))),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final Widget glyph;
  final String label;
  final bool warn;
  final VoidCallback onTap;

  const _DockItem({required this.glyph, required this.label, this.warn = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = warn ? p.warn : p.ink;
    return Expanded(
      flex: 10,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          color: warn ? p.warnWash : null,
          child: InkWell(
            onTap: onTap,
            child: IconTheme(
              data: IconThemeData(color: fg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  glyph,
                  const SizedBox(height: 2),
                  Text(label, style: context.type.bodyS.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Select mode's dark bar (3.3): Restyle, Mute and Delete for the
/// selection.
class BulkBar extends ConsumerWidget {
  const BulkBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final ids = ref.watch(editorUiControllerProvider.select((s) => s.selectedIds));
    final blocks = ref.watch(projectControllerProvider.select((s) => s.blocks));
    final controller = ref.read(projectControllerProvider.notifier);
    final selected = blocks.where((b) => ids.contains(b.id)).toList();
    final allMuted = selected.isNotEmpty && selected.every((b) => b.muted);
    final enabled = selected.isNotEmpty;

    Widget action(String label, VoidCallback onTap, {bool destructive = false}) {
      return TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          foregroundColor: destructive ? p.warnOnBlack : p.onInk,
          disabledForegroundColor: p.onInk.withValues(alpha: .35),
          backgroundColor: destructive && enabled ? p.warnOnBlack.withValues(alpha: .16) : null,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: t.bodyS.copyWith(fontSize: 13, fontWeight: destructive ? FontWeight.w700 : FontWeight.w600),
        ),
        child: Text(label),
      );
    }

    return Container(
      height: 66,
      padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
      decoration: BoxDecoration(color: p.inkSurface, borderRadius: BorderRadius.circular(24), boxShadow: p.toastShadow),
      child: Row(
        children: [
          Expanded(child: Text('${selected.length} selected', style: t.bodyS.copyWith(fontSize: 13, color: p.onInk.withValues(alpha: .8)))),
          action('Restyle', () => _restyle(context, controller, selected)),
          action(allMuted ? 'Unmute' : 'Mute', () => controller.bulkMute(ids)),
          action('Delete', () {
            controller.bulkDelete(ids);
            ref.read(editorUiControllerProvider.notifier).exitSelectMode();
            showEcToast(context, 'Removed ${plural(selected.length, 'block')}', actionLabel: 'Undo', onAction: controller.undo);
          }, destructive: true),
        ],
      ),
    );
  }

  /// Offers the styles the selection actually has: leaders for cast and
  /// crew lists, columns for name lists.
  Future<void> _restyle(BuildContext context, ProjectController controller, List<CreditBlock> selected) async {
    final hasPairs = selected.any((b) => b is PairListBlock);
    final hasNames = selected.any((b) => b is NameListBlock);
    if (!hasPairs && !hasNames) {
      showEcToast(context, 'Only cast, crew and name lists have a style to change');
      return;
    }
    final choice = await EcOptionSheet.show<(LeaderStyle?, int?)?>(
      context,
      title: 'Restyle ${plural(selected.length, 'block')}',
      selected: null,
      options: [
        if (hasPairs) ...const [
          EcOption((LeaderStyle.dots, null), 'Dot leaders', detail: 'Cast and crew'),
          EcOption((LeaderStyle.rule, null), 'Rule leaders', detail: 'Cast and crew'),
          EcOption((LeaderStyle.clean, null), 'No leaders', detail: 'Cast and crew'),
        ],
        if (hasNames) ...const [
          EcOption((null, 1), 'One column', detail: 'Name lists'),
          EcOption((null, 2), 'Two columns', detail: 'Name lists'),
          EcOption((null, 3), 'Three columns', detail: 'Name lists'),
        ],
      ],
    );
    if (choice == null) return;
    controller.restyle({for (final b in selected) b.id}, leader: choice.$1, columns: choice.$2);
  }
}
