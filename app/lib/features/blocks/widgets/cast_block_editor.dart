import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_chip.dart';
import '../../../core/widgets/ec_dashed_border.dart';
import '../../../core/widgets/ec_fields.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../../domain/models/credit_block.dart';
import '../../project/controllers/project_controller.dart';

const _leaders = [(LeaderStyle.dots, 'Dot leaders'), (LeaderStyle.rule, 'Rule'), (LeaderStyle.clean, 'None')];

/// 4.4 — a cast or crew list. Roles right-aligned and names left-aligned,
/// so each pair reads the way it will render; an A–Z rail for long casts.
class CastBlockEditor extends ConsumerStatefulWidget {
  final PairListBlock block;
  const CastBlockEditor({super.key, required this.block});

  @override
  ConsumerState<CastBlockEditor> createState() => _CastBlockEditorState();
}

class _CastBlockEditorState extends ConsumerState<CastBlockEditor> {
  final _rowKeys = <int, GlobalKey>{};

  GlobalKey _keyFor(int i) => _rowKeys.putIfAbsent(i, GlobalKey.new);

  /// Letters that begin a role (or, on a stacked cast, a name) — the rail
  /// only offers jumps that land somewhere.
  Map<String, int> _index(PairListBlock block) {
    final out = <String, int>{};
    for (final (i, r) in block.rows.indexed) {
      if (r is! PairCastRow) continue;
      final key = (block.alwaysStacked ? r.actor : r.role).trim();
      if (key.isEmpty) continue;
      out.putIfAbsent(key[0].toUpperCase(), () => i);
    }
    return Map.fromEntries(out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  void _jump(int i) {
    final context = _rowKeys[i]?.currentContext;
    if (context != null) Scrollable.ensureVisible(context, duration: EcMotion.base, alignment: .1);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final block = widget.block;
    final project = ref.watch(projectControllerProvider);
    final controller = ref.read(projectControllerProvider.notifier);
    final cg = computeCastGeometry(block, project.geometry);
    final aspect = project.settings.format.aspect;
    final letters = block.rows.length > 8 ? _index(block) : const <String, int>{};
    final roleHint = block.kind == BlockKind.crewTwoColumn ? 'Job' : 'Role';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!block.alwaysStacked) ...[
          EcSegmented(
            labels: [for (final l in _leaders) l.$2],
            selectedIndex: _leaders.indexWhere((l) => l.$1 == block.leader),
            onChanged: (i) => controller.setCastLeader(block.id, _leaders[i].$1),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Text('Centre gutter', style: t.bodyS.copyWith(fontSize: 12, color: p.ink2))),
              Text('${(block.gutter * 100).round()}%', style: t.mono.copyWith(fontSize: 12, color: p.accent, fontWeight: FontWeight.w500)),
            ],
          ),
          Slider(
            value: (block.gutter * 100).clamp(2, 16),
            min: 2,
            max: 16,
            divisions: 14,
            label: '${(block.gutter * 100).round()}%',
            onChanged: (v) => controller.setCastGutter(block.id, v / 100),
          ),
          Text(
            cg.collapse
                ? 'Too narrow for two columns on $aspect — rows stack as pairs.'
                : 'Holds two columns on $aspect.',
            style: t.caption.copyWith(fontSize: 11, color: cg.collapse ? p.warn : p.muted),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final (i, row) in block.rows.indexed)
                    Padding(
                      key: _keyFor(i),
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _RowEditor(
                        blockId: block.id,
                        index: i,
                        row: row,
                        roleHint: roleHint,
                        stacked: block.alwaysStacked,
                      ),
                    ),
                ],
              ),
            ),
            if (letters.isNotEmpty) ...[
              const SizedBox(width: 6),
              Column(
                children: [
                  for (final e in letters.entries)
                    InkWell(
                      onTap: () => _jump(e.value),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: Center(child: Text(e.key, style: t.mono.copyWith(fontSize: 9, color: p.accent))),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: _AddRow(label: '+ Row', onTap: () => controller.addCastRow(block.id))),
            const SizedBox(width: 8),
            Expanded(child: _AddRow(label: '+ "and" row', onTap: () => controller.addCastBillingRow(block.id))),
            const SizedBox(width: 8),
            Expanded(child: _AddRow(label: '+ Spacer', onTap: () => controller.addCastGapRow(block.id))),
          ],
        ),
      ],
    );
  }
}

class _RowEditor extends ConsumerWidget {
  final String blockId;
  final int index;
  final CastRow row;
  final String roleHint;
  final bool stacked;

  const _RowEditor({required this.blockId, required this.index, required this.row, required this.roleHint, required this.stacked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final controller = ref.read(projectControllerProvider.notifier);
    final number = row is PairCastRow ? '${index + 1}' : '·';
    final key = '$blockId/$index/${row.runtimeType}';

    final body = switch (row) {
      PairCastRow r => Row(
          children: [
            Expanded(
              child: EcCompactField(
                key: ValueKey('$key/role'),
                initialValue: r.role,
                hint: roleHint,
                textAlign: stacked ? TextAlign.center : TextAlign.end,
                onChanged: (v) => controller.updateCastRow(blockId, index, (x) => (x as PairCastRow).copyWith(role: v), field: 'role'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: EcCompactField(
                key: ValueKey('$key/name'),
                initialValue: r.actor,
                hint: 'Name',
                strong: true,
                onChanged: (v) => controller.updateCastRow(blockId, index, (x) => (x as PairCastRow).copyWith(actor: v), field: 'name'),
              ),
            ),
          ],
        ),
      SpanCastRow r => EcCompactField(
          key: ValueKey('$key/span'),
          initialValue: r.text,
          hint: '"and" · "with"',
          accent: true,
          textAlign: TextAlign.center,
          onChanged: (v) => controller.updateCastRow(blockId, index, (x) => (x as SpanCastRow).copyWith(text: v), field: 'span'),
        ),
      GapCastRow() => EcDashedBorder(
          radius: EcRadius.inner,
          child: SizedBox(height: 42, child: Center(child: Text(caps('Spacer'), style: t.pill.copyWith(color: p.faint)))),
        ),
    };

    return Row(
      children: [
        SizedBox(width: 18, child: Text(number, style: t.mono.copyWith(fontSize: 9.5, color: p.faint))),
        Expanded(child: body),
        SizedBox(
          width: 30,
          child: IconButton(
            tooltip: 'Remove row',
            onPressed: () => controller.removeCastRow(blockId, index),
            icon: Icon(Icons.close_rounded, size: 15, color: p.faint),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 42),
          ),
        ),
      ],
    );
  }
}

class _AddRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return EcDashedBorder(
      radius: EcRadius.pill,
      onTap: onTap,
      child: SizedBox(
        height: 42,
        child: Center(
          child: Text(label, style: context.type.bodyS.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: context.palette.ink2)),
        ),
      ),
    );
  }
}

/// The fast-entry bar pinned under the cast editor: type a role, Next,
/// type a name, Next — and the pair is a new row, ready for the next one.
/// Built for long casts typed from a call sheet.
class CastFastEntry extends ConsumerStatefulWidget {
  final String blockId;
  const CastFastEntry({super.key, required this.blockId});

  @override
  ConsumerState<CastFastEntry> createState() => _CastFastEntryState();
}

class _CastFastEntryState extends ConsumerState<CastFastEntry> {
  final _role = TextEditingController();
  final _name = TextEditingController();
  final _roleFocus = FocusNode();
  final _nameFocus = FocusNode();

  @override
  void dispose() {
    _role.dispose();
    _name.dispose();
    _roleFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// Role → name → new row: Next moves on from an empty field rather than
  /// adding a half-filled pair.
  void _next() {
    if (_roleFocus.hasFocus && _name.text.trim().isEmpty) {
      _nameFocus.requestFocus();
      return;
    }
    final role = _role.text.trim();
    final name = _name.text.trim();
    if (role.isEmpty && name.isEmpty) return;
    ref.read(projectControllerProvider.notifier).appendCastEntry(widget.blockId, role, name);
    _role.clear();
    _name.clear();
    _roleFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(EcRadius.group),
        border: Border.all(color: p.line),
        boxShadow: p.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(caps('Fast entry · Next hops role → name → row'), style: t.pill.copyWith(color: p.muted)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: EcCompactField(
                  controller: _role,
                  focusNode: _roleFocus,
                  hint: 'Role',
                  recessed: true,
                  height: 46,
                  textAlign: TextAlign.end,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _nameFocus.requestFocus(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: EcCompactField(
                  controller: _name,
                  focusNode: _nameFocus,
                  hint: 'Name',
                  recessed: true,
                  height: 46,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _next(),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                type: MaterialType.transparency,
                borderRadius: BorderRadius.circular(EcRadius.pill),
                clipBehavior: Clip.antiAlias,
                child: Ink(
                  width: 70,
                  height: 46,
                  decoration: BoxDecoration(gradient: p.primary, boxShadow: p.primaryShadow),
                  child: InkWell(
                    onTap: _next,
                    child: Center(child: Text('Next', style: t.button.copyWith(fontSize: 13, color: p.onInk))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
