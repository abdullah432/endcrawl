import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_chip.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/block_catalog.dart';
import '../../../domain/models/credit_block.dart';
import '../../editor/controllers/editor_ui_controller.dart';
import '../../project/controllers/project_controller.dart';
import 'block_editor_sheet.dart';

/// 4.1 — every block type, in seven groups, searchable and filterable.
///
/// The new block goes in after the one in focus, gets the focus itself,
/// and opens straight into its editor to be filled.
class AddBlockSheet extends ConsumerStatefulWidget {
  final String? afterTitle;
  const AddBlockSheet({super.key, this.afterTitle});

  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final focusedId = container.read(editorUiControllerProvider).focusedId;
    final blocks = container.read(projectControllerProvider).blocks;
    final after = blocks.where((b) => b.id == focusedId).firstOrNull;

    final kind = await showEcSheet<BlockKind>(
      context,
      builder: (_) => AddBlockSheet(afterTitle: after == null ? null : describeBlock(after).title),
    );
    if (kind == null || !context.mounted) return;

    final block = newBlockOf(kind);
    container.read(projectControllerProvider.notifier).insertBlock(block, afterId: after?.id);
    container.read(editorUiControllerProvider.notifier).focus(block.id);
    await BlockEditorSheet.show(context, block.id);
  }

  @override
  ConsumerState<AddBlockSheet> createState() => _AddBlockSheetState();
}

class _AddBlockSheetState extends ConsumerState<AddBlockSheet> {
  String _query = '';
  BlockGroup? _group;

  bool _matches(BlockKind k) {
    if (_group != null && k.group != _group) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return k.label.toLowerCase().contains(q) || k.description.toLowerCase().contains(q) || k.code.toLowerCase() == q;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    final visible = BlockKind.values.where(_matches).toList();

    return EcSheet(
      title: 'Add block',
      eyebrow: widget.afterTitle == null ? 'Adds to the end' : 'Insert after · ${widget.afterTitle}',
      maxHeightFraction: 0.94,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              EcChip(
                label: 'All · ${BlockKind.values.length}',
                selected: _group == null,
                height: 32,
                onTap: () => setState(() => _group = null),
              ),
              for (final g in BlockGroup.values)
                EcChip(
                  label: g.label.split(' ').first,
                  selected: _group == g,
                  height: 32,
                  onTap: () => setState(() => _group = _group == g ? null : g),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No block type matches “$_query”.', textAlign: TextAlign.center, style: t.bodyS.copyWith(color: p.muted)),
            ),
          for (final g in BlockGroup.values)
            if (visible.any((k) => k.group == g)) ...[
              EcSectionLabel(
                g.label,
                trailing: Text('${visible.where((k) => k.group == g).length}', style: t.section),
              ),
              _KindGroup(kinds: [for (final k in visible) if (k.group == g) k]),
              const SizedBox(height: 18),
            ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(EcRadius.pill),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: p.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: t.body.copyWith(fontSize: 14, color: p.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search ${BlockKind.values.length} block types',
                hintStyle: t.body.copyWith(fontSize: 14, color: p.faint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindGroup extends StatelessWidget {
  final List<BlockKind> kinds;
  const _KindGroup({required this.kinds});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.glassStrong,
        borderRadius: BorderRadius.circular(EcRadius.card),
        border: Border.all(color: p.glassEdge),
        boxShadow: p.rowShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (final (i, k) in kinds.indexed) ...[
              if (i > 0) Divider(height: 1, color: p.line),
              Semantics(
                button: true,
                label: 'Add ${k.label}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(k),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                      child: Row(
                        children: [
                          EcCodeTile(k.code),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(k.label, style: t.titleS.copyWith(fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(k.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption),
                              ],
                            ),
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: p.accentWash, shape: BoxShape.circle),
                            child: Icon(Icons.add_rounded, size: 18, color: p.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
