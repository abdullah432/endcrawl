import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../project/controllers/project_controller.dart';
import '../controllers/editor_ui_controller.dart';
import 'block_card.dart';

/// The document: an ordered, reorderable list of typed blocks (§6 of the
/// brief). Long-press a card to lift it and drag to reorder — Flutter's
/// `ReorderableListView` gives us that, plus edge auto-scroll, for free.
class BlockList extends ConsumerWidget {
  const BlockList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectControllerProvider);
    final ui = ref.watch(editorUiControllerProvider);
    final controller = ref.read(projectControllerProvider.notifier);
    final editorUi = ref.read(editorUiControllerProvider.notifier);
    final blocks = project.blocks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(EcSpace.s4, EcSpace.s2, EcSpace.s4, EcSpace.s2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${blocks.length} blocks · drag to reorder',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 10.5, letterSpacing: 1.5, color: EcColors.textTertiary),
                ),
              ),
              TextButton(
                onPressed: editorUi.toggleSelectMode,
                style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero),
                child: Text(
                  ui.selectMode ? 'Done' : 'Select',
                  style: TextStyle(fontSize: 11.5, color: ui.selectMode ? EcColors.accentPrimary : EcColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: blocks.isEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: EcSpace.s4),
                  child: _EmptyState(onAdd: () => editorUi.openSheet(EditorSheet.add)),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(EcSpace.s4, 0, EcSpace.s4, EcSpace.s6),
                  itemCount: blocks.length + 1,
                  onReorder: (from, to) {
                    if (from >= blocks.length || to > blocks.length) return;
                    final adjusted = to > from ? to - 1 : to;
                    controller.reorder(from, adjusted);
                  },
                  itemBuilder: (context, i) {
                    if (i == blocks.length) {
                      return Padding(
                        key: const ValueKey('add-block-footer'),
                        padding: const EdgeInsets.only(top: EcSpace.s2),
                        child: OutlinedButton(
                          onPressed: () => editorUi.openSheet(EditorSheet.add),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: EcColors.borderStrong),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.lg)),
                          ),
                          child: const Text('+ Add block', style: TextStyle(fontSize: 13, color: EcColors.textSecondary)),
                        ),
                      );
                    }
                    final b = blocks[i];
                    return BlockCard(key: ValueKey(b.id), block: b, index: i);
                  },
                ),
        ),
        if (ui.selectMode) _BulkBar(selectedCount: ui.selectedIds.length),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: EcSpace.s3),
      padding: const EdgeInsets.symmetric(horizontal: EcSpace.s4, vertical: EcSpace.s6),
      decoration: BoxDecoration(border: Border.all(color: EcColors.borderStrong, style: BorderStyle.solid), borderRadius: BorderRadius.circular(EcRadius.lg)),
      child: Column(
        children: [
          const Text('No blocks yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: EcColors.textPrimary)),
          const SizedBox(height: 6),
          const Text(
            'Add a title card, or paste a cast list and split it into two columns.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: EcColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: EcSpace.s4),
          FilledButton(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: EcColors.accentPrimary,
              foregroundColor: EcColors.accentInk,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: const Text('Add first block'),
          ),
        ],
      ),
    );
  }
}

class _BulkBar extends ConsumerWidget {
  final int selectedCount;
  const _BulkBar({required this.selectedCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(projectControllerProvider.notifier);
    final ui = ref.read(editorUiControllerProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(EcSpace.s3, 0, EcSpace.s3, EcSpace.s4),
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: EcSpace.s3),
      decoration: BoxDecoration(
        color: EcColors.surfaceOverlay,
        border: Border.all(color: EcColors.borderStrong),
        borderRadius: BorderRadius.circular(EcRadius.xl),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 18))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '$selectedCount selected',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(fontSize: 12, color: EcColors.textSecondary),
            ),
          ),
          _bulkBtn('Restyle', EcColors.textPrimary, () => controller.bulkToggleCastLeader(ui.selectedIds)),
          _bulkBtn('Mute', EcColors.textPrimary, () => controller.bulkMute(ui.selectedIds)),
          _bulkBtn('Delete', EcColors.warn, () => controller.bulkDelete(ui.selectedIds)),
        ],
      ),
    );
  }

  Widget _bulkBtn(String label, Color color, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 6), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      child: Text(label, style: TextStyle(fontSize: 12, color: color)),
    );
  }
}
