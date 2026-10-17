import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatting.dart';
import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../domain/models/block_catalog.dart';
import '../../../domain/models/credit_block.dart';
import '../../editor/controllers/editor_ui_controller.dart';
import '../../editor/editor_actions.dart';
import '../../editor/widgets/read_only_banner.dart';
import '../../project/controllers/project_controller.dart';
import 'cast_block_editor.dart';
import 'generic_block_editor.dart';

/// The selected block's settings, in a panel beside the monitor — what the
/// phone's edit sheet (4.4) becomes on a tablet (T3.1, under the monitor)
/// and a desktop browser (D11, the right-hand pane). The same editors as the
/// sheet; edits apply as they are typed, each an undo step.
///
/// On a read-only project (the free plan's cap, or the web preview) every
/// setting can still be read; touching a field explains why it can't change.
class BlockInspector extends ConsumerWidget {
  /// The design's padding differs by layout: tight under the tablet monitor,
  /// roomier in the desktop pane.
  final EdgeInsetsGeometry padding;

  /// The cast fast-entry bar — on the desktop, where Tab runs role → name →
  /// row (D11). Under the tablet's monitor the rows need the room.
  final bool fastEntry;

  /// How many columns a cast's rows run in — two under the tablet monitor.
  final int castColumns;

  const BlockInspector({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 16),
    this.fastEntry = true,
    this.castColumns = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final focusedId = ref.watch(editorUiControllerProvider.select((s) => s.focusedId));
    final project = ref.watch(projectControllerProvider);
    final blocks = project.blocks;
    final index = blocks.indexWhere((b) => b.id == focusedId);
    final readOnly = ref.watch(editorReadOnlyProvider);

    if (index < 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined, color: p.faint),
              const SizedBox(height: 10),
              Text(
                'Select a block to edit it here.',
                style: t.body.copyWith(color: p.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final block = blocks[index];
    final seconds = project.blockSeconds[block.id];
    final title = switch (block) {
      PairListBlock(:final header) when header.trim().isNotEmpty => sentenceCase(header),
      _ => describeBlock(block).title,
    };
    final detail = describeBlock(block).detail;
    final eyebrow = [
      'Block ${(index + 1).toString().padLeft(2, '0')}',
      block.kind.code,
      if (seconds != null) formatClock(seconds),
    ].join(' · ');

    Widget editor = KeyedSubtree(
      key: ValueKey(block.id),
      child: block is PairListBlock
          ? CastBlockEditor(block: block, columns: castColumns)
          : GenericBlockEditor(block: block),
    );
    if (readOnly) {
      // Every setting stays readable; any touch explains the lock instead.
      editor = Stack(
        children: [
          AbsorbPointer(child: editor),
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => explainReadOnly(context)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: padding.resolve(TextDirection.ltr).copyWith(bottom: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(caps(eyebrow), style: t.eyebrow.copyWith(fontSize: 10)),
                    const SizedBox(height: 4),
                    Semantics(header: true, child: Text(title, style: t.displayM.copyWith(fontSize: 28, height: 1.05))),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyS.copyWith(fontSize: 12, color: p.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (!readOnly) _BlockMenu(blockId: block.id),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(padding: padding.resolve(TextDirection.ltr).copyWith(top: 14), child: editor),
        ),
        if (fastEntry && block is PairListBlock && !readOnly)
          Padding(
            padding: padding.resolve(TextDirection.ltr).copyWith(top: 0),
            child: CastFastEntry(key: ValueKey('fast-${block.id}'), blockId: block.id),
          ),
      ],
    );
  }
}

enum _BlockAction { duplicate, delete }

/// The selected block's "…" menu (D11): Duplicate and Delete — the phone's
/// swipe actions, for a pointer.
class _BlockMenu extends ConsumerWidget {
  final String blockId;
  const _BlockMenu({required this.blockId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    return PopupMenuButton<_BlockAction>(
      tooltip: 'Block actions',
      icon: Icon(Icons.more_horiz_rounded, size: 20, color: p.ink2),
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (action) {
        switch (action) {
          case _BlockAction.duplicate:
            final copy = ref.read(projectControllerProvider.notifier).duplicateBlock(blockId);
            ref.read(editorUiControllerProvider.notifier).focus(copy);
          case _BlockAction.delete:
            removeBlockWithUndo(context, blockId);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _BlockAction.duplicate,
          child: Text('Duplicate', style: t.row),
        ),
        PopupMenuItem(
          value: _BlockAction.delete,
          child: Text('Delete block', style: t.row.copyWith(color: p.warn)),
        ),
      ],
    );
  }
}
