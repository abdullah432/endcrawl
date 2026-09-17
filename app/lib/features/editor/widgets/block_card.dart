import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/theme/tokens.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../project/controllers/project_controller.dart';
import '../../../domain/models/credit_block.dart';
import '../controllers/editor_ui_controller.dart';
import 'block_summary.dart';

/// One block card in the editor's document list: long-press to reorder
/// (handled by the enclosing `ReorderableListView`), swipe to
/// duplicate/mute/delete, tap to open the block's edit sheet and jump the
/// monitor to it (§6 of the brief).
class BlockCard extends ConsumerWidget {
  final CreditBlock block;
  final int index;

  const BlockCard({super.key, required this.block, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectControllerProvider);
    final ui = ref.watch(editorUiControllerProvider);
    final controller = ref.read(projectControllerProvider.notifier);
    final summary = summarizeBlock(block, project);
    final selected = ui.selectedIds.contains(block.id);
    final isCast = block is CastBlock;

    return Slidable(
      key: ValueKey('slidable-${block.id}'),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.62,
        children: [
          _slideAction('Duplicate', EcColors.surfaceHi, EcColors.textSecondary, () => controller.duplicateBlock(block.id)),
          _slideAction(block.muted ? 'Unmute' : 'Mute', EcColors.surfaceHi, EcColors.textSecondary, () => controller.toggleMute(block.id)),
          _slideAction('Delete', const Color(0x2EE2705C), EcColors.warn, () => controller.deleteBlock(block.id)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: EcSpace.s2),
        child: Material(
          color: EcColors.surfaceRaised,
          borderRadius: BorderRadius.circular(EcRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(EcRadius.lg),
            onTap: () {
              if (ui.selectMode) {
                ref.read(editorUiControllerProvider.notifier).toggleSelected(block.id);
                return;
              }
              final y = project.measurements.blockY[block.id];
              if (y != null) ref.read(playbackControllerProvider.notifier).seekToBlockTop(y);
              ref.read(editorUiControllerProvider.notifier).openSheet(EditorSheet.block, blockId: block.id);
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 62),
              padding: const EdgeInsets.all(EcSpace.s3),
              decoration: BoxDecoration(
                border: Border.all(color: selected ? EcColors.accentDim : EcColors.borderHairline),
                borderRadius: BorderRadius.circular(EcRadius.lg),
              ),
              child: Row(
                children: [
                  if (ui.selectMode) ...[
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? EcColors.accentPrimary : Colors.transparent,
                        border: Border.all(color: selected ? EcColors.accentPrimary : EcColors.borderStrong, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: selected ? const Icon(Icons.check, size: 13, color: EcColors.accentInk) : null,
                    ),
                    const SizedBox(width: EcSpace.s3),
                  ],
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isCast ? EcColors.accentWash : EcColors.surfaceHi,
                      borderRadius: BorderRadius.circular(EcRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      block.glyph,
                      style: TextStyle(fontFamily: EcFonts.mono, fontSize: 9, color: isCast ? EcColors.accentPrimary : EcColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: EcSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                summary.title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: block.muted ? EcColors.textDisabled : EcColors.textPrimary),
                              ),
                            ),
                            if (block.fontMissing) _badge('Font', EcColors.warn, EcColors.warn.withValues(alpha: .5)),
                            if (block.muted) _badge('Muted', EcColors.textTertiary, EcColors.borderStrong),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(summary.meta, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: EcColors.textTertiary)),
                      ],
                    ),
                  ),
                  Text(summary.duration, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 10.5, color: EcColors.textTertiary)),
                  const SizedBox(width: EcSpace.s2),
                  const Icon(Icons.drag_handle, size: 16, color: EcColors.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color, Color border) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(EcRadius.sm)),
        child: Text(label, style: TextStyle(fontSize: 9, letterSpacing: 1, color: color)),
      ),
    );
  }

  Widget _slideAction(String label, Color bg, Color fg, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: SizedBox(
        width: 68,
        child: CustomSlidableAction(
          onPressed: (_) => onTap(),
          backgroundColor: bg,
          borderRadius: BorderRadius.circular(EcRadius.md),
          child: Text(label, style: TextStyle(fontSize: 10, color: fg), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
