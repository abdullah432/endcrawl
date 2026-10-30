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
import '../../home/tablet_layout.dart';

/// 4.2 / 4.3 — bulk entry. Raw text on the left, the split result on the
/// right, updated live. Lines no rule can split are listed underneath to
/// be fixed in place; "Add" counts only rows that are complete.
class PasteSheet extends ConsumerStatefulWidget {
  const PasteSheet({super.key});

  static Future<void> show(BuildContext context) async {
    if (lockedOnWeb(context, LockedAction.paste)) return;
    final tablet = context.tabletLayout;
    // T4.2: full screen beside nothing else; P4.2: a full-height sheet,
    // raw over structured.
    final added = tablet == TabletLayout.landscape
        ? await Navigator.of(context).push<int>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const EcSheetPresentation(
                dialog: true,
                child: Scaffold(body: SafeArea(child: PasteSheet())),
              ),
            ),
          )
        : await showEcSheet<int>(
            context,
            dialogWidth: 1080,
            fromBottom: tablet == TabletLayout.portrait,
            builder: (_) => const PasteSheet(),
          );
    if (added != null && added > 0 && context.mounted) showEcToast(context, 'Added ${plural(added, 'row')}');
  }

  @override
  ConsumerState<PasteSheet> createState() => _PasteSheetState();
}

class _PasteSheetState extends ConsumerState<PasteSheet> {
  final _raw = TextEditingController();
  final _rawFocus = FocusNode();

  @override
  void dispose() {
    _raw.dispose();
    _rawFocus.dispose();
    super.dispose();
  }

  /// Raw lines (0-based, counting blank ones) behind the parser's
  /// numbering, which skips blank lines — the gutter shows the raw ones.
  Map<int, int> _rawLines() {
    final map = <int, int>{};
    var ordinal = 0;
    for (final (i, line) in _raw.text.split('\n').indexed) {
      if (line.trim().isEmpty) continue;
      map[ordinal++] = i;
    }
    return map;
  }

  /// "Edit line" (T4.2): the caret goes to the flagged line in the raw
  /// text, selected, so it can be retyped with a separator.
  void _editLine(int index) {
    final line = _rawLines()[index];
    if (line == null) return;
    final lines = _raw.text.split('\n');
    final start = lines.take(line).fold<int>(0, (sum, l) => sum + l.length + 1);
    _raw.selection = TextSelection(baseOffset: start, extentOffset: start + lines[line].length);
    _rawFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pasteControllerProvider);
    final controller = ref.read(pasteControllerProvider.notifier);
    final rows = state.rows;
    final importing = state.mode == PasteMode.file;
    final target = controller.target;

    if (EcSheetPresentation.isDialog(context)) return _wide(context, state, controller);
    if (context.tabletLayout == TabletLayout.portrait) return _portrait(context, state, controller);

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
    final tablet = context.isTablet;
    final fullScreen = tablet;
    final height = (MediaQuery.sizeOf(context).height - 48).clamp(420.0, 760.0);
    // The parser counts only non-blank lines; the gutter counts them all.
    final rawLines = _rawLines();
    final flaggedRaw = {for (final i in unparsedLines) ?rawLines[i]};

    return Container(
      height: fullScreen ? null : height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: BorderRadius.circular(fullScreen ? 0 : EcRadius.sheet),
        boxShadow: fullScreen ? null : EcDialog.shadow,
      ),
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
                        EcEyebrow(
                          target == null
                              ? 'Bulk entry · new cast block'
                              : 'Bulk entry · into ${describeBlock(target).title}',
                        ),
                        const SizedBox(height: 6),
                        Semantics(
                          header: true,
                          child: Text('Paste & split', style: t.displayL.copyWith(fontSize: tablet ? 44 : 36)),
                        ),
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
                                    focusNode: _rawFocus,
                                    mono: true,
                                    expands: true,
                                    lineNumbers: true,
                                    fontSize: tablet ? 14 : null,
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
                                      child: Text(
                                        caps('Structured · ${plural(parsed.length - unparsed.length, 'row')}'),
                                        style: t.section,
                                      ),
                                    ),
                                    if (unparsed.isNotEmpty)
                                      Text(
                                        caps('${unparsed.length} needs a look'),
                                        style: t.section.copyWith(color: p.warn),
                                      ),
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
                                            padding: EdgeInsets.all(tablet ? 12 : 8),
                                            children: [
                                              // T4.2: the rows, then each line that
                                              // won't split as its own alert.
                                              if (tablet) ...[
                                                for (final r in parsed)
                                                  if (r.ok) _ParsedRow(row: r, large: true),
                                                for (final r in unparsed)
                                                  _FlagAlert(
                                                    row: r,
                                                    onEdit: () => _editLine(r.index),
                                                    onSkip: () => controller.skip(r.index),
                                                  ),
                                              ] else
                                                for (final r in parsed)
                                                  if (unparsedLines.contains(r.index))
                                                    _UnparsedRow(row: r, state: state, controller: controller)
                                                  else if (r.ok)
                                                    _ParsedRow(row: r),
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
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: p.line)),
                ),
                child: Row(
                  children: [
                    Text('Split on', style: t.bodyS.copyWith(color: p.ink2)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final d in _rules(state))
                            EcChip(
                              label: '${d.label} · ${state.counts[d.id]}',
                              mono: !tablet,
                              height: tablet ? 44 : 32,
                              selected: state.rule.id == d.id,
                              onTap: () => controller.pickRule(d.id),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    EcButton.secondary(
                      label: tablet ? 'Swap' : 'Swap columns',
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

  /// The split rules offered: "2+ spaces" only when it would split
  /// something, as the design's four chips.
  List<DelimiterOption> _rules(PasteState state) => [
    for (final d in kDelimiters)
      if (d.id != 'spaces' || state.counts[d.id]! > 0 || state.rule.id == d.id) d,
  ];

  /// P4.2 — the portrait tablet: raw on top, structured under it, read in
  /// the order the split happens; the flagged line gets its own alert next
  /// to the result, and Add sits at the bottom edge.
  Widget _portrait(BuildContext context, PasteState state, PasteController controller) {
    final p = context.palette;
    final t = context.type;
    final target = controller.target;
    final parsed = state.parsed;
    final unparsed = state.unparsed;
    final rows = state.rows;
    final importing = state.mode == PasteMode.file;
    final rawLines = _rawLines();
    final flaggedRaw = {for (final r in unparsed) ?rawLines[r.index]};
    final lines = rawLines.length;
    final ok = parsed.where((r) => r.ok).toList();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + keyboard),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: p.sheet, borderRadius: BorderRadius.circular(36), boxShadow: EcDialog.shadow),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 26, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EcEyebrow(
                            target == null
                                ? 'Bulk entry · new cast block'
                                : 'Bulk entry · into ${describeBlock(target).title}',
                          ),
                          const SizedBox(height: 6),
                          Semantics(
                            header: true,
                            child: Text('Paste & split', style: t.displayL.copyWith(fontSize: 38)),
                          ),
                        ],
                      ),
                    ),
                    EcCircleButton.surface(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 300,
                    child: EcSegmented(
                      labels: const ['Paste', 'Import file'],
                      selectedIndex: state.mode.index,
                      onChanged: (i) => controller.setMode(PasteMode.values[i]),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
                  children: importing
                      ? const [
                          EcNotice(
                            tone: EcTone.neutral,
                            icon: Icons.upload_file_rounded,
                            title: 'Import from a file is coming soon',
                            body: 'Until then, copy the list from your call sheet or spreadsheet and paste it here.',
                          ),
                        ]
                      : [
                          Text(caps('Raw · ${plural(lines, 'line')}'), style: t.section),
                          const SizedBox(height: 8),
                          EcTextArea(
                            controller: _raw,
                            focusNode: _rawFocus,
                            mono: true,
                            lineNumbers: true,
                            fontSize: 13,
                            minLines: 6,
                            maxLines: 12,
                            flaggedLines: flaggedRaw,
                            hint: 'Renny — Sofia Alvarez\nMarcus — Idris Oyelaran',
                            onChanged: controller.setRaw,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(child: Text(caps('Structured · ${plural(ok.length, 'row')}'), style: t.section)),
                              if (unparsed.isNotEmpty)
                                Text(caps('${unparsed.length} needs a look'), style: t.section.copyWith(color: p.warn)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _StructuredTable(rows: ok),
                          for (final r in unparsed)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: _FlagAlert(
                                row: r,
                                onEdit: () => _editLine(r.index),
                                onSkip: () => controller.skip(r.index),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text('Split on', style: t.bodyS.copyWith(color: p.ink2)),
                              ),
                              for (final d in _rules(state))
                                EcChip(
                                  label: '${d.label} · ${state.counts[d.id]}',
                                  ink: true,
                                  selected: state.rule.id == d.id,
                                  onTap: () => controller.pickRule(d.id),
                                ),
                            ],
                          ),
                        ],
                ),
              ),
              if (!importing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 26),
                  child: Row(
                    children: [
                      EcButton.secondary(
                        label: 'Swap',
                        leading: const Icon(Icons.swap_horiz_rounded, size: 18),
                        expand: false,
                        size: EcButtonSize.large,
                        onPressed: controller.toggleSwap,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: EcButton(
                          label: rows.isEmpty ? 'Add rows' : 'Add ${plural(rows.length, 'row')}',
                          size: EcButtonSize.large,
                          onPressed: rows.isEmpty ? null : () => Navigator.of(context).pop(controller.apply()),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
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

    final rawColumn = Column(
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
    );
    final structuredColumn = Column(
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
    );
    return [
      // Side by side on the phone; the portrait tablet stacks them (P4.2).
      SizedBox(
        height: 190,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: rawColumn),
            const SizedBox(width: 8),
            Expanded(child: structuredColumn),
          ],
        ),
      ),
      const SizedBox(height: 14),
      EcSectionLabel('Split on · lines matched'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final d in _rules(state))
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

  /// The tablet's field-sized cells (T4.2).
  final bool large;
  const _ParsedRow({required this.row, this.large = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    Widget cell(String text, {bool end = false, bool strong = false}) => Expanded(
      child: Container(
        height: large ? 44 : 34,
        padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10),
        alignment: end ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: p.sheet,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.line),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (large ? t.body.copyWith(fontSize: 14.5) : t.bodyS).copyWith(
            color: strong ? p.ink : p.muted,
            fontWeight: strong ? FontWeight.w500 : null,
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: large ? 8 : 6),
      child: Row(
        children: [
          cell(row.left, end: true),
          SizedBox(width: large ? 8 : 6),
          cell(row.right, strong: true),
        ],
      ),
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
            TextSpan(
              children: [
                TextSpan(
                  text: 'Line ${row.index + 1}',
                  style: TextStyle(color: p.warn, fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' has no separator. Split it here:'),
              ],
            ),
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
          child: Text(
            left,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: base.copyWith(color: row.ok ? p.muted : p.warn),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: base.copyWith(color: row.ok ? p.ink : p.warn),
          ),
        ),
      ],
    );
  }
}

/// P4.2's parsed rows: one divided table, the role right-aligned and
/// muted, the name bold — as the roll will set them.
class _StructuredTable extends StatelessWidget {
  final List<ParsedRow> rows;
  const _StructuredTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Split rows appear here as you paste.', style: t.caption),
            )
          : Column(
              children: [
                for (final (i, r) in rows.indexed)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: i == 0 ? null : Border(top: BorderSide(color: p.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.left,
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.body.copyWith(fontSize: 14, color: p.muted),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            r.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.body.copyWith(fontSize: 14, color: p.ink, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// A line no rule could split (T4.2, P4.2): flagged, never fixed silently.
/// Edit line puts the caret on it in the raw text; Skip leaves it out.
class _FlagAlert extends StatelessWidget {
  final ParsedRow row;
  final VoidCallback onEdit;
  final VoidCallback onSkip;
  const _FlagAlert({required this.row, required this.onEdit, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
        color: p.warnWash,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.warnLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Line ${row.index + 1}',
                    style: TextStyle(color: p.warn, fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' has no separator.'),
                ],
              ),
              style: t.body.copyWith(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          EcButton.secondary(label: 'Edit line', expand: false, size: EcButtonSize.small, onPressed: onEdit),
          const SizedBox(width: 4),
          EcButton.text(label: 'Skip', expand: false, size: EcButtonSize.small, onPressed: onSkip),
        ],
      ),
    );
  }
}
