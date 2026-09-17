import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../project/controllers/project_controller.dart';
import '../../../../domain/models/credit_block.dart';
import '../../../../domain/engine/roll_engine.dart';

const _kLeaderOptions = [
  (LeaderStyle.dots, 'Dotted leaders'),
  (LeaderStyle.clean, 'Clean gutter'),
  (LeaderStyle.rule, 'Hairline rule'),
];

const _kCollapseOptions = [
  (CastCollapseMode.auto, 'Auto'),
  (CastCollapseMode.never, 'Always 2-col'),
  (CastCollapseMode.always, 'Always stacked'),
];

/// The two-column cast block's dedicated editor: leader style, centre
/// gutter width, collapse behavior, per-row editing with an A–Z jump
/// rail for long lists, and a keyboard-anchored fast-entry bar
/// (Tab/Next hops role → name → new row) — §6 and §7 of the brief.
class CastBlockEditor extends ConsumerStatefulWidget {
  final String blockId;
  const CastBlockEditor({super.key, required this.blockId});

  @override
  ConsumerState<CastBlockEditor> createState() => _CastBlockEditorState();
}

class _CastBlockEditorState extends ConsumerState<CastBlockEditor> {
  final _scrollController = ScrollController();
  final _entryRole = TextEditingController();
  final _entryName = TextEditingController();
  final _entryNameFocus = FocusNode();

  static const _rowHeight = 46.0;

  @override
  void dispose() {
    _scrollController.dispose();
    _entryRole.dispose();
    _entryName.dispose();
    _entryNameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectControllerProvider);
    final controller = ref.read(projectControllerProvider.notifier);
    final block = project.blocks.firstWhere((b) => b.id == widget.blockId) as CastBlock;
    final cg = computeCastGeometry(block, project.geometry);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final l in _kLeaderOptions)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: EcSpace.s2),
                  child: _pill(l.$2, block.leader == l.$1, () => controller.setCastLeader(block.id, l.$1)),
                ),
              ),
          ],
        ),
        const SizedBox(height: EcSpace.s3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Centre gutter', style: TextStyle(fontSize: 11.5, color: EcColors.textSecondary)),
            Text('${cg.gutter.round()} px · ${(block.gutter * 100).round()}%', style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 11.5, color: EcColors.accentPrimary)),
          ],
        ),
        Slider(value: block.gutter * 100, min: 2, max: 16, onChanged: (v) => controller.setCastGutter(block.id, v / 100)),
        Text(
          cg.collapse
              ? 'Columns are ${cg.colWidth.round()}px — below the ${cg.need.round()}px legibility floor for a ${cg.maxChars}-character name, so rows stack as pairs.'
              : 'Columns are ${cg.colWidth.round()}px, clear of the ${cg.need.round()}px floor. True two-column alignment.',
          style: TextStyle(fontSize: 10.5, color: cg.collapse ? EcColors.warn : EcColors.textTertiary),
        ),
        const SizedBox(height: EcSpace.s3),
        Row(
          children: [
            for (final c in _kCollapseOptions)
              Expanded(child: _segment(c.$2, block.collapse == c.$1, () => controller.setCastCollapse(block.id, c.$1))),
          ],
        ),
        const SizedBox(height: EcSpace.s3),
        SizedBox(
          height: 320,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: block.rows.length,
                  itemBuilder: (context, i) => SizedBox(height: _rowHeight, child: _rowEditor(block, cg, i, controller)),
                ),
              ),
              SizedBox(
                width: 18,
                child: ListView(
                  children: [
                    for (final ch in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''))
                      InkWell(
                        onTap: () => _jumpTo(block, ch),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(ch, style: TextStyle(fontFamily: EcFonts.mono, fontSize: 8, color: _hasLetter(block, ch) ? EcColors.accentPrimary : EcColors.textDisabled)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: EcSpace.s2),
        Row(
          children: [
            Expanded(child: _dashedButton('+ Row', () => controller.addCastRow(block.id))),
            const SizedBox(width: EcSpace.s2),
            Expanded(child: _dashedButton('+ "and" row', () => controller.addCastBillingRow(block.id))),
            const SizedBox(width: EcSpace.s2),
            Expanded(child: _dashedButton('+ Spacer', () => controller.addCastGapRow(block.id))),
          ],
        ),
        const SizedBox(height: EcSpace.s4),
        Container(
          padding: const EdgeInsets.only(top: EcSpace.s3),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: EcColors.borderHairline))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('FAST ENTRY — NEXT HOPS ROLE → NAME → NEW ROW', style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: EcColors.textTertiary)),
              const SizedBox(height: EcSpace.s2),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _entryRole,
                      textAlign: TextAlign.right,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _entryNameFocus.requestFocus(),
                      style: const TextStyle(fontSize: 13, color: EcColors.textPrimary),
                      decoration: _entryDecoration('Role'),
                    ),
                  ),
                  const SizedBox(width: EcSpace.s2),
                  Expanded(
                    child: TextField(
                      controller: _entryName,
                      focusNode: _entryNameFocus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _commit(block.id, controller),
                      style: const TextStyle(fontSize: 13, color: EcColors.textPrimary),
                      decoration: _entryDecoration('Name'),
                    ),
                  ),
                  const SizedBox(width: EcSpace.s2),
                  SizedBox(
                    width: 64,
                    height: 44,
                    child: FilledButton(
                      onPressed: () => _commit(block.id, controller),
                      style: FilledButton.styleFrom(backgroundColor: EcColors.accentPrimary, foregroundColor: EcColors.accentInk, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.sm))),
                      child: const Text('Next', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _commit(String blockId, ProjectController controller) {
    if (_entryRole.text.isEmpty && _entryName.text.isEmpty) return;
    controller.appendCastEntry(blockId, _entryRole.text, _entryName.text);
    _entryRole.clear();
    _entryName.clear();
    FocusScope.of(context).requestFocus(FocusNode());
  }

  bool _hasLetter(CastBlock block, String ch) {
    return block.rows.any((r) => r is PairCastRow && r.role.toUpperCase().startsWith(ch));
  }

  void _jumpTo(CastBlock block, String ch) {
    final i = block.rows.indexWhere((r) => r is PairCastRow && r.role.toUpperCase().startsWith(ch));
    if (i < 0) return;
    _scrollController.animateTo((i * _rowHeight).clamp(0, _scrollController.position.maxScrollExtent), duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  InputDecoration _entryDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: EcColors.surfaceSunken,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: EcSpace.s3, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(EcRadius.sm), borderSide: const BorderSide(color: EcColors.borderStrong)),
    );
  }

  Widget _rowEditor(CastBlock block, CastGeometry cg, int i, ProjectController controller) {
    final r = block.rows[i];
    final overLength = r is PairCastRow && r.role.length > cg.maxChars - 1 && cg.collapse;

    Widget field({required String hint, required String value, required ValueChanged<String> onChanged, TextAlign align = TextAlign.left, bool warn = false}) {
      return Expanded(
        child: TextFormField(
          key: ValueKey('cast-${block.id}-$i-$hint'),
          initialValue: value,
          onChanged: onChanged,
          textAlign: align,
          style: const TextStyle(fontSize: 12, color: EcColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: EcColors.surfaceRaised,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: EcSpace.s2, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(EcRadius.sm), borderSide: BorderSide(color: warn ? EcColors.warn.withValues(alpha: .5) : EcColors.borderHairline)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 16, child: Text(r is PairCastRow ? (i + 1).toString().padLeft(2, '0') : '·', style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 9.5, color: EcColors.textDisabled))),
          const SizedBox(width: EcSpace.s2),
          if (r is PairCastRow) ...[
            field(hint: 'Role', value: r.role, align: TextAlign.right, warn: overLength, onChanged: (v) => controller.updateCastRow(block.id, i, (row) => (row as PairCastRow).copyWith(role: v))),
            const SizedBox(width: EcSpace.s2),
            field(hint: 'Name', value: r.actor, onChanged: (v) => controller.updateCastRow(block.id, i, (row) => (row as PairCastRow).copyWith(actor: v))),
          ] else if (r is SpanCastRow) ...[
            field(hint: '"and" / "with"', value: r.text, align: TextAlign.center, onChanged: (v) => controller.updateCastRow(block.id, i, (row) => (row as SpanCastRow).copyWith(text: v))),
          ] else ...[
            const Expanded(child: Text('blank spacer row', style: TextStyle(fontSize: 11, color: EcColors.textTertiary))),
          ],
          IconButton(
            onPressed: () => controller.removeCastRow(block.id, i),
            icon: const Icon(Icons.close, size: 15, color: EcColors.textDisabled),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 40),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? EcColors.accentWash : EcColors.surfaceRaised,
      borderRadius: BorderRadius.circular(EcRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(EcRadius.full),
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(EcRadius.full), border: Border.all(color: selected ? EcColors.accentPrimary : EcColors.borderHairline)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: selected ? EcColors.accentPrimary : EcColors.textSecondary)),
        ),
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EcRadius.full),
        child: Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? EcColors.surfaceHi : Colors.transparent, borderRadius: BorderRadius.circular(EcRadius.full)),
          child: Text(label, style: TextStyle(fontSize: 11.5, color: selected ? EcColors.textPrimary : EcColors.textTertiary)),
        ),
      ),
    );
  }

  Widget _dashedButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(EcRadius.md),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(EcRadius.md), border: Border.all(color: EcColors.borderStrong)),
        child: Text(label, style: const TextStyle(fontSize: 12, color: EcColors.textSecondary)),
      ),
    );
  }
}
