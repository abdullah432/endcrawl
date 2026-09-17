import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../project/controllers/project_controller.dart';
import '../../project/models/credit_block.dart';
import '../models/paste_models.dart';

enum PasteMode { raw, file }

class PasteFix {
  final String left;
  final String right;
  const PasteFix({this.left = '', this.right = ''});
  PasteFix copyWith({String? left, String? right}) => PasteFix(left: left ?? this.left, right: right ?? this.right);
}

class PasteState {
  final PasteMode mode;
  final String raw;
  final String delimiterId;
  final bool swapColumns;
  final Map<int, PasteFix> fixes;

  const PasteState({
    this.mode = PasteMode.raw,
    this.raw = kPasteRawSeed,
    this.delimiterId = 'dash',
    this.swapColumns = false,
    this.fixes = const {},
  });

  PasteState copyWith({
    PasteMode? mode,
    String? raw,
    String? delimiterId,
    bool? swapColumns,
    Map<int, PasteFix>? fixes,
  }) {
    return PasteState(
      mode: mode ?? this.mode,
      raw: raw ?? this.raw,
      delimiterId: delimiterId ?? this.delimiterId,
      swapColumns: swapColumns ?? this.swapColumns,
      fixes: fixes ?? this.fixes,
    );
  }

  DelimiterOption get delimiter => kDelimiters.firstWhere((d) => d.id == delimiterId, orElse: () => kDelimiters.first);
  List<ParsedRow> get parsedRows => parsePastedText(raw, delimiter, swapColumns);
  List<ParsedRow> get okRows => parsedRows.where((r) => r.ok).toList();
  List<ParsedRow> get badRows => parsedRows.where((r) => !r.ok).toList();
}

/// The "Paste & Split" bulk-entry feature (§7 of the brief): a live,
/// rule-based delimiter parser with no AI and no guessing — anything it
/// can't split is flagged for the user to fix inline.
class PasteController extends Notifier<PasteState> {
  @override
  PasteState build() => const PasteState();

  void setMode(PasteMode m) => state = state.copyWith(mode: m);
  void setRaw(String v) => state = state.copyWith(raw: v);
  void setDelimiter(String id) => state = state.copyWith(delimiterId: id);
  void toggleSwap() => state = state.copyWith(swapColumns: !state.swapColumns);

  void setFixLeft(int index, String v) {
    final next = {...state.fixes};
    next[index] = (next[index] ?? const PasteFix()).copyWith(left: v);
    state = state.copyWith(fixes: next);
  }

  void setFixRight(int index, String v) {
    final next = {...state.fixes};
    next[index] = (next[index] ?? const PasteFix()).copyWith(right: v);
    state = state.copyWith(fixes: next);
  }

  void reset() => state = const PasteState();

  /// Adds the parsed rows to an existing cast block (or creates one) and
  /// closes the sheet — port of `applyParse()`.
  void apply() {
    final ok = state.okRows;
    final bad = state.badRows;
    final fixed = [
      for (final r in bad)
        if ((state.fixes[r.index]?.left ?? '').isNotEmpty && (state.fixes[r.index]?.right ?? '').isNotEmpty)
          PairCastRow(role: state.fixes[r.index]!.left, actor: state.fixes[r.index]!.right),
    ];
    final rows = <CastRow>[
      for (final r in ok) PairCastRow(role: r.left, actor: r.right),
      ...fixed,
    ];

    final project = ref.read(projectControllerProvider.notifier);
    final blocks = ref.read(projectControllerProvider).blocks;
    CastBlock? target;
    for (final b in blocks) {
      if (b is CastBlock) {
        target = b;
        break;
      }
    }
    if (target != null) {
      project.setCastRows(target.id, rows);
    } else {
      project.addBlock(CastBlock(id: newBlockId(), rows: rows));
    }
    reset();
  }
}

final pasteControllerProvider = NotifierProvider<PasteController, PasteState>(PasteController.new);
