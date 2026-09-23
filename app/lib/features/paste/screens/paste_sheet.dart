import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_chip.dart';
import '../../../core/widgets/ec_fields.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/block_catalog.dart';
import '../controllers/paste_controller.dart';
import '../models/paste_models.dart';

/// 4.2 / 4.3 — bulk entry. Raw text on the left, the split result on the
/// right, updated live. Lines no rule can split are listed underneath to
/// be fixed in place; "Add" counts only rows that are complete.
class PasteSheet extends ConsumerStatefulWidget {
  const PasteSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final added = await showEcSheet<int>(context, builder: (_) => const PasteSheet());
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
