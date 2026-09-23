import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../blocks/screens/add_block_sheet.dart';
import '../../project/controllers/project_controller.dart';
import '../controllers/editor_ui_controller.dart';
import 'block_row.dart';

/// The document: an ordered list of blocks under a count and a
/// Select/Done switch (3.1, 3.3). Drag the handle — or long-press a row —
/// to reorder.
class BlockList extends ConsumerWidget {
  /// Clear space under the last row for the floating dock.
  final double bottomInset;

  const BlockList({super.key, this.bottomInset = 100});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final blocks = ref.watch(projectControllerProvider.select((s) => s.blocks));
    final ui = ref.watch(editorUiControllerProvider);
    final uiController = ref.read(editorUiControllerProvider.notifier);
    final controller = ref.read(projectControllerProvider.notifier);

    final count = ui.selectMode ? '${ui.selectedIds.length} of ${blocks.length} selected' : plural(blocks.length, 'block');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              Expanded(child: Text(caps(count), style: t.eyebrow)),
              if (blocks.isNotEmpty)
                TextButton(
                  onPressed: ui.selectMode ? uiController.exitSelectMode : uiController.enterSelectMode,
                  style: TextButton.styleFrom(
                    foregroundColor: p.accent,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: t.bodyS.copyWith(fontSize: 12.5, fontWeight: ui.selectMode ? FontWeight.w700 : FontWeight.w600),
                  ),
                  child: Text(ui.selectMode ? 'Done' : 'Select'),
                ),
            ],
          ),
        ),
        Expanded(
          child: blocks.isEmpty
              ? ListView(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset),
                  children: const [_EmptyState()],
                )
              : SlidableAutoCloseBehavior(
                  child: ReorderableListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset),
                    buildDefaultDragHandles: false,
                    itemCount: blocks.length,
                    onReorderItem: controller.reorder,
                    proxyDecorator: (child, _, _) => Material(type: MaterialType.transparency, child: child),
                    itemBuilder: (context, i) => BlockRow(key: ValueKey(blocks[i].id), block: blocks[i], index: i),
                  ),
                ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return EcGlassCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Text('No blocks yet', style: t.titleM),
          const SizedBox(height: 6),
          Text(
            'Add a title card, or paste a cast list and split it into two columns.',
            textAlign: TextAlign.center,
            style: t.bodyS,
          ),
          const SizedBox(height: 16),
          EcButton(
            label: 'Add first block',
            size: EcButtonSize.medium,
            expand: false,
            onPressed: () => AddBlockSheet.show(context),
          ),
        ],
      ),
    );
  }
}
