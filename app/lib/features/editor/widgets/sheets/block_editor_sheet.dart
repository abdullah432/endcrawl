import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/ec_sheet.dart';
import '../../../project/controllers/project_controller.dart';
import '../../../../domain/models/credit_block.dart';
import 'cast_block_editor.dart';
import 'generic_block_editor.dart';

class BlockEditorSheet extends ConsumerWidget {
  final String blockId;
  const BlockEditorSheet({super.key, required this.blockId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(projectControllerProvider.select((s) => s.blocks));
    CreditBlock? block;
    for (final b in blocks) {
      if (b.id == blockId) {
        block = b;
        break;
      }
    }
    if (block == null) return const SizedBox.shrink();

    return EcSheet(
      title: 'Edit block',
      child: block is PairListBlock ? CastBlockEditor(blockId: blockId) : GenericBlockEditor(block: block),
    );
  }
}
