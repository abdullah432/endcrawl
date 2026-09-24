import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/block_catalog.dart';
import '../../../domain/models/credit_block.dart';
import '../../blocks/screens/block_editor_sheet.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../project/controllers/project_controller.dart';
import '../controllers/editor_ui_controller.dart';
import '../editor_actions.dart';

/// One block in the editor's list (3.1): code tile, title, detail, its
/// share of the runtime, and a drag handle.
///
/// Tap focuses it, moves the monitor to it and opens its editor (4.4).
/// Swipe left for Duplicate or Delete (3.5). In select mode (3.3) the
/// handle gives way to a check, so reordering and selecting never share a
/// gesture.
class BlockRow extends ConsumerWidget {
  final CreditBlock block;
  final int index;

  const BlockRow({super.key, required this.block, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final ui = ref.watch(editorUiControllerProvider);
    final seconds = ref.watch(projectControllerProvider.select((s) => s.blockSeconds[block.id]));
    final culprit = ref.watch(projectControllerProvider.select((s) => s.readabilityCulprit == block.id));
    final description = describeBlock(block);

    final selecting = ui.selectMode;
    final checked = selecting && ui.selectedIds.contains(block.id);
    final focused = !selecting && ui.focusedId == block.id;
    final warn = culprit && !selecting && !ui.warnDismissed;
    final raised = checked || focused || warn;

    final shape = BorderRadius.circular(EcRadius.row);
    final border = warn
        ? Border.all(color: p.warnLine, width: 1.5)
        : raised
            ? Border.all(color: p.accentSolid, width: 1.5)
            : Border.all(color: p.glassEdge);

    void onTap() {
      final ui = ref.read(editorUiControllerProvider.notifier);
      if (selecting) {
        ui.toggleSelected(block.id);
        return;
      }
      ui.focus(block.id);
      ref.read(playbackControllerProvider.notifier).seekToBlock(block.id);
      BlockEditorSheet.show(context, block.id);
    }

    final row = AnimatedContainer(
      duration: EcMotion.fast,
      decoration: BoxDecoration(
        color: raised ? p.surface : p.glass,
        borderRadius: shape,
        border: border,
        boxShadow: focused ? [BoxShadow(color: p.accentWash, spreadRadius: 4)] : (raised ? null : p.rowShadow),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                if (selecting) ...[_Check(checked: checked), const SizedBox(width: 12)],
                EcCodeTile(block.kind.code, tone: warn ? EcTone.warn : (focused ? EcTone.accent : EcTone.neutral)),
                const SizedBox(width: 12),
                Expanded(
                  child: Opacity(
                    opacity: block.muted ? .5 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(description.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleS.copyWith(fontSize: 13.5)),
                            ),
                            if (warn) ...[const SizedBox(width: 6), const EcStatusPill('Too fast', tone: EcTone.warn)],
                            if (block.muted) ...[const SizedBox(width: 6), const EcStatusPill('Muted')],
                            if (block.fontMissing) ...[const SizedBox(width: 6), const EcStatusPill('Font', tone: EcTone.warn)],
                          ],
                        ),
                        if (description.detail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(description.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(seconds == null ? '—' : formatClock(seconds), style: t.mono.copyWith(fontSize: 10.5)),
                if (!selecting)
                  ReorderableDragStartListener(
                    index: index,
                    child: Tooltip(
                      message: 'Drag to reorder',
                      child: SizedBox(width: 32, height: 36, child: Icon(Icons.drag_handle_rounded, size: 18, color: p.faint)),
                    ),
                  )
                else
                  const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: selecting
          ? row
          : Slidable(
              key: ValueKey('slide-${block.id}'),
              groupTag: 'blocks',
              endActionPane: ActionPane(
                motion: const BehindMotion(),
                extentRatio: 0.46,
                children: [
                  _SwipeAction(
                    icon: Icons.copy_all_rounded,
                    label: 'Duplicate',
                    background: p.line2,
                    foreground: p.ink,
                    onTap: () {
                      final copy = ref.read(projectControllerProvider.notifier).duplicateBlock(block.id);
                      ref.read(editorUiControllerProvider.notifier).focus(copy);
                    },
                  ),
                  _SwipeAction(
                    icon: Icons.backspace_outlined,
                    label: 'Delete',
                    background: p.warnFill,
                    foreground: p.onInk,
                    last: true,
                    onTap: () => removeBlockWithUndo(context, block.id),
                  ),
                ],
              ),
              child: ReorderableDelayedDragStartListener(index: index, child: row),
            ),
    );
  }
}

class _Check extends StatelessWidget {
  final bool checked;
  const _Check({required this.checked});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedContainer(
      duration: EcMotion.fast,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: checked ? p.primary : null,
        border: checked ? null : Border.all(color: p.line2, width: 1.5),
      ),
      child: checked ? Icon(Icons.check_rounded, size: 15, color: p.onInk) : null,
    );
  }
}

class _SwipeAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final bool last;
  final VoidCallback onTap;

  const _SwipeAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    this.last = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomSlidableAction(
      onPressed: (_) => onTap(),
      backgroundColor: background,
      foregroundColor: foreground,
      padding: EdgeInsets.zero,
      borderRadius: last ? const BorderRadius.horizontal(right: Radius.circular(EcRadius.row)) : BorderRadius.zero,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: foreground),
          const SizedBox(height: 3),
          Text(label, style: context.type.bodyS.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: foreground)),
        ],
      ),
    );
  }
}
