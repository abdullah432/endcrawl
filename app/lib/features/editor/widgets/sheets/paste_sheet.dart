import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/ec_chip.dart';
import '../../../../core/widgets/ec_sheet.dart';
import '../../../paste/controllers/paste_controller.dart';
import '../../../paste/models/paste_models.dart';

const _kMockFiles = [
  ('Cast_final_v4.csv', '2.1 KB · 31 rows · comma'),
  ('crew_list.tsv', '4.8 KB · 62 rows · tab'),
];

/// Bulk entry without AI (§7 of the brief): a live, rule-based delimiter
/// parser with a raw/structured two-pane preview. Anything the parser
/// can't split is flagged, not guessed, and fixed inline.
class PasteSheet extends ConsumerStatefulWidget {
  const PasteSheet({super.key});

  @override
  ConsumerState<PasteSheet> createState() => _PasteSheetState();
}

class _PasteSheetState extends ConsumerState<PasteSheet> {
  late final TextEditingController _rawCtrl;

  @override
  void initState() {
    super.initState();
    _rawCtrl = TextEditingController(text: ref.read(pasteControllerProvider).raw);
  }

  @override
  void dispose() {
    _rawCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pasteControllerProvider);
    final controller = ref.read(pasteControllerProvider.notifier);
    final ok = state.okRows;
    final bad = state.badRows;
    final allLines = state.raw.split('\n').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    return EcSheet(
      title: 'Bulk entry',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcSegmented(
            labels: const ['Paste & split', 'Import file'],
            selectedIndex: state.mode == PasteMode.raw ? 0 : 1,
            onChanged: (i) => controller.setMode(i == 0 ? PasteMode.raw : PasteMode.file),
          ),
          const SizedBox(height: EcSpace.s3),
          if (state.mode == PasteMode.raw) ...[
            SizedBox(
              height: 168,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const EcSectionLabel('Raw'),
                        Expanded(
                          child: TextField(
                            controller: _rawCtrl,
                            onChanged: controller.setRaw,
                            maxLines: null,
                            expands: true,
                            style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 10, color: EcColors.textSecondary, height: 1.55),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: EcColors.surfaceSunken,
                              hintText: 'Paste your cast list…',
                              contentPadding: const EdgeInsets.all(EcSpace.s2),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(EcRadius.md), borderSide: const BorderSide(color: EcColors.borderHairline)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: EcSpace.s2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EcSectionLabel('Structured · ${ok.length} of ${allLines.length}'),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(EcSpace.s2),
                            decoration: BoxDecoration(color: EcColors.surfaceSunken, border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.md)),
                            child: ListView(
                              children: [
                                for (final r in state.parsedRows)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 1),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(r.left, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, maxLines: 1,
                                              style: TextStyle(fontFamily: EcFonts.mono, fontSize: 9.5, color: r.ok ? EcColors.textSecondary : EcColors.warn)),
                                        ),
                                        const Padding(padding: EdgeInsets.symmetric(horizontal: 3), child: Text('·', style: TextStyle(color: EcColors.textDisabled, fontSize: 9.5))),
                                        Expanded(
                                          child: Text(r.ok ? r.right : 'needs a look', overflow: TextOverflow.ellipsis, maxLines: 1,
                                              style: TextStyle(fontFamily: EcFonts.mono, fontSize: 9.5, color: r.ok ? EcColors.textPrimary : EcColors.warn)),
                                        ),
                                      ],
                                    ),
                                  ),
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
            const SizedBox(height: EcSpace.s3),
            const EcSectionLabel('Delimiter · detected candidates'),
            Wrap(
              spacing: EcSpace.s2,
              runSpacing: EcSpace.s2,
              children: [
                for (final d in kDelimiters)
                  EcChip(
                    label: d.label,
                    selected: state.delimiterId == d.id,
                    onTap: () => controller.setDelimiter(d.id),
                    trailing: Text(allLines.where((t) => t.split(d.pattern).length > 1).length.toString(), style: const TextStyle(fontSize: 10, color: EcColors.textTertiary)),
                  ),
              ],
            ),
            const SizedBox(height: EcSpace.s3),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.toggleSwap,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), foregroundColor: EcColors.textSecondary, side: const BorderSide(color: EcColors.borderHairline), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md))),
                    child: const Text('⇄ Swap columns', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: EcSpace.s2),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      controller.apply();
                      Navigator.of(context).maybePop();
                    },
                    style: FilledButton.styleFrom(backgroundColor: EcColors.accentPrimary, foregroundColor: EcColors.accentInk, minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md))),
                    child: Text('Add ${ok.length} rows', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            if (bad.isNotEmpty) ...[
              const SizedBox(height: EcSpace.s3),
              Container(
                padding: const EdgeInsets.all(EcSpace.s3),
                decoration: BoxDecoration(color: EcColors.warnWash, border: Border.all(color: EcColors.warn.withValues(alpha: .4)), borderRadius: BorderRadius.circular(EcRadius.md)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${bad.length} ${bad.length == 1 ? 'row needs a look' : 'rows need a look'} — nothing was guessed. Fix them here:', style: const TextStyle(fontSize: 11.5, color: EcColors.textPrimary)),
                    const SizedBox(height: EcSpace.s2),
                    for (final r in bad)
                      Padding(
                        padding: const EdgeInsets.only(bottom: EcSpace.s2),
                        child: Row(
                          children: [
                            Expanded(
                              child: _miniField(
                                hint: 'Role',
                                value: state.fixes[r.index]?.left ?? r.left,
                                onChanged: (v) => controller.setFixLeft(r.index, v),
                              ),
                            ),
                            const SizedBox(width: EcSpace.s2),
                            Expanded(
                              child: _miniField(
                                hint: 'Name',
                                value: state.fixes[r.index]?.right ?? '',
                                onChanged: (v) => controller.setFixRight(r.index, v),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ] else ...[
            for (final f in _kMockFiles)
              Padding(
                padding: const EdgeInsets.only(bottom: EcSpace.s2),
                child: Material(
                  color: EcColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(EcRadius.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(EcRadius.md),
                    onTap: () {
                      controller.setMode(PasteMode.raw);
                      controller.setRaw(kPasteRawSeed);
                      controller.setDelimiter('dash');
                      _rawCtrl.text = kPasteRawSeed;
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.all(EcSpace.s3),
                      decoration: BoxDecoration(border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.md)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.$1, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 12.5, color: EcColors.textPrimary)),
                          Text(f.$2, style: const TextStyle(fontSize: 11, color: EcColors.textTertiary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: EcSpace.s2),
            const EcSectionLabel('Column mapping'),
            for (final m in const [('Column A', 'Role'), ('Column B', 'Name'), ('Column C', 'Ignore')])
              Container(
                margin: const EdgeInsets.only(bottom: EcSpace.s2),
                padding: const EdgeInsets.symmetric(horizontal: EcSpace.s3, vertical: EcSpace.s2),
                decoration: BoxDecoration(color: EcColors.surfaceRaised, border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.md)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(m.$1, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 11.5, color: EcColors.textSecondary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: EcColors.surfaceHi, borderRadius: BorderRadius.circular(EcRadius.full)),
                      child: Text(m.$2, style: const TextStyle(fontSize: 11.5, color: EcColors.textPrimary)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _miniField({required String hint, required String value, required ValueChanged<String> onChanged}) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12, color: EcColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: EcColors.surfaceSunken,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: EcSpace.s2, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(EcRadius.sm), borderSide: const BorderSide(color: EcColors.borderHairline)),
      ),
    );
  }
}
