import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_chip.dart';
import '../../../core/widgets/ec_fields.dart';
import '../../../core/widgets/ec_dialog.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/block_catalog.dart';
import '../controllers/paste_controller.dart';
import '../models/paste_models.dart';
import '../../access/controllers/web_access.dart';
import '../../access/widgets/locked_dialog.dart';

/// 4.2 / 4.3 — bulk entry. Raw text on the left, the split result on the
/// right, updated live. Lines no rule can split are listed underneath to
/// be fixed in place; "Add" counts only rows that are complete.
class PasteSheet extends ConsumerStatefulWidget {
  const PasteSheet({super.key});

  static Future<void> show(BuildContext context) async {
    if (lockedOnWeb(context, LockedAction.paste)) return;
    final added = await showEcSheet<int>(context, dialogWidth: 1080, builder: (_) => const PasteSheet());
    if (added != null && added > 0 && context.mounted) showEcToast(context, 'Added ${plural(added, 'row')}');
  }

  @override
  ConsumerState<PasteSheet> createState() => _PasteSheetState();
}

class _PasteSheetState extends ConsumerState<PasteSheet> {
  final _raw = TextEditingController();

  @override
  void dispose() {
    _raw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pasteControllerProvider);
    final controller = ref.read(pasteControllerProvider.notifier);
    final rows = state.rows;
    final importing = state.mode == PasteMode.file;
    final target = controller.target;

    if (EcSheetPresentation.isDialog(context)) return _wide(context, state, controller);

    return EcSheet(
      title: 'Bulk entry',
      maxHeightFraction: 0.92,
      footer: importing
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    target == null ? 'Adds a new cast block' : 'Adds to “${describeBlock(target).title}”',
                    textAlign: TextAlign.center,
                    style: context.type.caption,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      EcButton.secondary(
                        label: 'Swap',
                        leading: const Icon(Icons.swap_horiz_rounded, size: 18),
                        expand: false,
                        size: EcButtonSize.medium,
                        onPressed: controller.toggleSwap,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: EcButton(
                          label: rows.isEmpty ? 'Add rows' : 'Add ${plural(rows.length, 'row')}',
                          size: EcButtonSize.medium,
                          onPressed: rows.isEmpty ? null : () => Navigator.of(context).pop(controller.apply()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EcSegmented(
            labels: const ['Paste & split', 'Import file'],
            selectedIndex: state.mode.index,
            onChanged: (i) => controller.setMode(PasteMode.values[i]),
          ),
          const SizedBox(height: 14),
          if (importing)
            const EcNotice(
              tone: EcTone.neutral,
              icon: Icons.upload_file_rounded,
              title: 'Import from a file is coming soon',
              body: 'Until then, copy the list from your call sheet or spreadsheet and paste it here.',
            )
          else
            ..._pasteBody(context, state, controller),
        ],
      ),
    );
  }

  /// T4.2 / D12: raw text left, parsed rows right, rebuilt live; the split
  /// rules and the actions along the foot. A line that won't split is
  /// flagged on both sides and fixed in place — never guessed at.
  Widget _wide(BuildContext context, PasteState state, PasteController controller) {
    final p = context.palette;
    final t = context.type;
    final target = controller.target;
    final parsed = state.parsed;
    final unparsed = state.unparsed;
    final unparsedLines = {for (final r in unparsed) r.index};
    final rows = state.rows;
    final importing = state.mode == PasteMode.file;
    final lines = _raw.text.split('\n').where((l) => l.trim().isNotEmpty).length;
    final height = (MediaQuery.sizeOf(context).height - 48).clamp(420.0, 760.0);
    // The parser counts only non-blank lines; the gutter counts them all.
    final flaggedRaw = <int>{};
    var ordinal = 0;
    for (final (i, line) in _raw.text.split('\n').indexed) {
      if (line.trim().isEmpty) continue;
      if (unparsedLines.contains(ordinal)) flaggedRaw.add(i);
      ordinal++;
    }

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: p.sheet, borderRadius: BorderRadius.circular(EcRadius.sheet), boxShadow: EcDialog.shadow),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 26, 22, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EcEyebrow(target == null ? 'Bulk entry · new cast block' : 'Bulk entry · into ${describeBlock(target).title}'),
                        const SizedBox(height: 6),
                        Semantics(header: true, child: Text('Paste & split', style: t.displayL.copyWith(fontSize: 36))),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: EcSegmented(
                      labels: const ['Paste', 'Import file'],
                      selectedIndex: state.mode.index,
                      onChanged: (i) => controller.setMode(PasteMode.values[i]),
                    ),
                  ),
                  const SizedBox(width: 10),
                  EcCircleButton.surface(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: importing
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: EcNotice(
                          tone: EcTone.neutral,
                          icon: Icons.upload_file_rounded,
                          title: 'Import from a file is coming soon',
                          body: 'Until then, copy the list from your call sheet or spreadsheet and paste it here.',
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(caps('Raw · ${plural(lines, 'line')}'), style: t.section),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: EcTextArea(
                                    controller: _raw,
                                    mono: true,
                                    expands: true,
                                    lineNumbers: true,
                                    flaggedLines: flaggedRaw,
                                    hint: 'Renny — Sofia Alvarez\nMarcus — Idris Oyelaran',
                                    onChanged: controller.setRaw,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(caps('Structured · ${plural(parsed.length - unparsed.length, 'row')}'),
                                          style: t.section),
                                    ),
                                    if (unparsed.isNotEmpty)
                                      Text(caps('${plural(unparsed.length, 'line')} needs a look'),
                                          style: t.section.copyWith(color: p.warn)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: p.surface,
                                      borderRadius: BorderRadius.circular(EcRadius.field),
                                      border: Border.all(color: p.line),
                                    ),
                                    child: parsed.isEmpty
                                        ? Center(child: Text('Split rows appear here as you paste.', style: t.caption))
                                        : ListView(
                                            padding: const EdgeInsets.all(8),
                                            children: [
                                              for (final r in parsed)
                                                unparsedLines.contains(r.index)
                                                    ? _UnparsedRow(row: r, state: state, controller: controller)
                                                    : _ParsedRow(row: r),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (!importing)
              Container(
                padding: const EdgeInsets.fromLTRB(28, 14, 22, 18),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
                child: Row(
                  children: [
                    Text('Split on', style: t.bodyS.copyWith(color: p.ink2)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final d in kDelimiters)
                            EcChip(
                              label: '${d.label} · ${state.counts[d.id]}',
                              mono: true,
                              height: 32,
                              selected: state.rule.id == d.id,
                              onTap: () => controller.pickRule(d.id),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    EcButton.secondary(
                      label: 'Swap columns',
                      leading: const Icon(Icons.swap_horiz_rounded, size: 18),
                      expand: false,
                      size: EcButtonSize.medium,
                      onPressed: controller.toggleSwap,
                    ),
                    const SizedBox(width: 8),
                    EcButton(
                      label: rows.isEmpty ? 'Add rows' : 'Add ${plural(rows.length, 'row')}',
                      size: EcButtonSize.medium,
                      expand: false,
                      onPressed: rows.isEmpty ? null : () => Navigator.of(context).pop(controller.apply()),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _pasteBody(BuildContext context, PasteState state, PasteController controller) {
    final p = context.palette;
    final t = context.type;
    final parsed = state.parsed;
    final unparsed = state.unparsed;
    final counts = state.counts;
    final structuredLabel = parsed.isEmpty
        ? 'Structured'
        : unparsed.isEmpty
            ? 'Structured · ${plural(parsed.length, 'row')}'
            : 'Structured · ${parsed.length - unparsed.length} of ${parsed.length}';

    return [
      SizedBox(
        height: 190,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(caps('Raw'), style: t.section),
                  const SizedBox(height: 6),
                  Expanded(
                    child: EcTextArea(
                      controller: _raw,
                      mono: true,
                      expands: true,
                      hint: 'Renny — Sofia Alvarez\nMarcus — Idris Oyelaran',
                      onChanged: controller.setRaw,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(caps(structuredLabel), style: t.section.copyWith(color: p.accent)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: p.accentWash,
                        borderRadius: BorderRadius.circular(EcRadius.field),
                        border: Border.all(color: p.accentLine),
                      ),
                      child: parsed.isEmpty
                          ? Text('Split rows appear here as you paste.', style: t.caption)
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: [for (final r in parsed) _StructuredLine(row: r)],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      EcSectionLabel('Split on · lines matched'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final d in kDelimiters)
            EcChip(
              label: d.label,
              mono: true,
              filled: true,
              selected: state.rule.id == d.id,
              onTap: () => controller.pickRule(d.id),
              trailing: Text(
                '${counts[d.id]}',
                style: t.mono.copyWith(
                  fontSize: 11.5,
                  color: state.rule.id == d.id ? p.onInk.withValues(alpha: .75) : p.faint,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        'Rules, not guesswork. Each chip shows how many lines it would split; change it and the right column rebuilds.',
        style: t.caption,
      ),
      if (unparsed.isNotEmpty) ...[
        const SizedBox(height: 16),
        EcNotice(
          tone: EcTone.warn,
          title: '${plural(unparsed.length, 'line')} couldn’t be split.',
          body: 'Nothing was guessed — fix them here.',
        ),
        const SizedBox(height: 10),
        for (final r in unparsed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: EcCompactField(
                    key: ValueKey('fix-role-${r.index}-${r.left}'),
                    initialValue: state.fixes[r.index]?.role ?? '',
                    hint: 'Role',
                    recessed: true,
                    textAlign: TextAlign.end,
                    onChanged: (v) => controller.fixRole(r.index, v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: EcCompactField(
                    key: ValueKey('fix-name-${r.index}-${r.left}'),
                    initialValue: state.fixes[r.index]?.name ?? r.left,
                    hint: 'Name',
                    recessed: true,
                    onChanged: (v) => controller.fixName(r.index, v),
                  ),
                ),
              ],
            ),
          ),
      ],
    ];
  }
}

/// A split row on the wide layout: role right-aligned, name left, as the
/// roll will set them.
class _ParsedRow extends StatelessWidget {
  final ParsedRow row;
  const _ParsedRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    Widget cell(String text, {bool end = false, bool strong = false}) => Expanded(
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: end ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: p.sheet,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.line),
            ),
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyS.copyWith(color: strong ? p.ink : p.muted, fontWeight: strong ? FontWeight.w600 : null)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [cell(row.left, end: true), const SizedBox(width: 6), cell(row.right, strong: true)]),
    );
  }
}

/// A line that wouldn't split, flagged and fixed in place.
class _UnparsedRow extends StatelessWidget {
  final ParsedRow row;
  final PasteState state;
  final PasteController controller;
  const _UnparsedRow({required this.row, required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.warnWash,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.warnLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Line ${row.index + 1}', style: TextStyle(color: p.warn, fontWeight: FontWeight.w700)),
              TextSpan(text: ' has no separator. Split it here:'),
            ]),
            style: t.bodyS,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: EcCompactField(
                  key: ValueKey('fix-role-${row.index}-${row.left}'),
                  initialValue: state.fixes[row.index]?.role ?? '',
                  hint: 'Role',
                  textAlign: TextAlign.end,
                  onChanged: (v) => controller.fixRole(row.index, v),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: EcCompactField(
                  key: ValueKey('fix-name-${row.index}-${row.left}'),
                  initialValue: state.fixes[row.index]?.name ?? row.left,
                  hint: 'Name',
                  onChanged: (v) => controller.fixName(row.index, v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StructuredLine extends StatelessWidget {
  final ParsedRow row;
  const _StructuredLine({required this.row});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = context.type.mono.copyWith(fontSize: 9.5, height: 1.7);
    final left = row.ok ? row.left : '?';
    final right = row.ok ? row.right : 'unparsed';
    return Row(
      children: [
        Expanded(
          child: Text(left,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: base.copyWith(color: row.ok ? p.muted : p.warn)),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(right, maxLines: 1, overflow: TextOverflow.ellipsis, style: base.copyWith(color: row.ok ? p.ink : p.warn)),
        ),
      ],
    );
  }
}
