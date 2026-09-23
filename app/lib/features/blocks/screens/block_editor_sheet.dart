import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../domain/models/block_catalog.dart';
import '../../../domain/models/credit_block.dart';
import '../../editor/editor_actions.dart';
import '../../project/controllers/project_controller.dart';
import '../widgets/cast_block_editor.dart';
import '../widgets/generic_block_editor.dart';

enum _SheetResult { delete }

/// 4.4 — edit one block. Cast and crew lists get their dedicated editor
/// with fast entry; every other kind a form for its fields. Edits apply
/// as they are typed, each an undo step in the editor.
class BlockEditorSheet extends ConsumerWidget {
  final String blockId;
  const BlockEditorSheet({super.key, required this.blockId});

  static Future<void> show(BuildContext context, String blockId) async {
    final result = await showEcSheet<_SheetResult>(context, builder: (_) => BlockEditorSheet(blockId: blockId));
    if (result == _SheetResult.delete && context.mounted) await removeBlockWithUndo(context, blockId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final block = ref.watch(projectControllerProvider.select((s) => s.blocks.where((b) => b.id == blockId).firstOrNull));
    if (block == null) return const SizedBox.shrink();

    final title = switch (block) {
      PairListBlock(:final header) when header.trim().isNotEmpty => sentenceCase(header),
      _ => describeBlock(block).title,
    };
    final delete = Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => Navigator.of(context).pop(_SheetResult.delete),
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: const Text('Delete block'),
        style: TextButton.styleFrom(foregroundColor: context.palette.warn),
      ),
    );

    if (block is PairListBlock) {
      return EcSheet(
        eyebrow: 'Edit block · ${block.kind.code}',
        title: title,
        maxHeightFraction: 0.94,
        footer: CastFastEntry(blockId: block.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [CastBlockEditor(block: block), const SizedBox(height: 8), delete],
        ),
      );
    }
    return EcSheet(
      eyebrow: 'Edit block · ${block.kind.code}',
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [GenericBlockEditor(block: block), const SizedBox(height: 4), delete],
      ),
    );
  }
}
