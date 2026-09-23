import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/credit_block.dart';
import '../../editor/controllers/editor_ui_controller.dart';
import '../../project/controllers/project_controller.dart';
import '../models/paste_models.dart';

enum PasteMode { paste, file }

/// A line that couldn't be split, being fixed in place (4.3). The name
/// starts as the whole line; [role] starts empty — nothing is guessed.
class PasteFix {
  final String? role;
  final String? name;
  const PasteFix({this.role, this.name});
  PasteFix copyWith({String? role, String? name}) => PasteFix(role: role ?? this.role, name: name ?? this.name);
}

class PasteState {
  final PasteMode mode;
  final String raw;

  /// The rule the person picked; until they pick, the one that splits the
  /// most lines.
  final String? pickedRuleId;
  final bool swapColumns;
  final Map<int, PasteFix> fixes;

  const PasteState({
    this.mode = PasteMode.paste,
    this.raw = '',
    this.pickedRuleId,
    this.swapColumns = false,
    this.fixes = const {},
  });

  PasteState copyWith({PasteMode? mode, String? raw, String? pickedRuleId, bool? swapColumns, Map<int, PasteFix>? fixes}) {
    return PasteState(
      mode: mode ?? this.mode,
      raw: raw ?? this.raw,
      pickedRuleId: pickedRuleId ?? this.pickedRuleId,
      swapColumns: swapColumns ?? this.swapColumns,
      fixes: fixes ?? this.fixes,
    );
  }

  List<String> get lines => pastedLines(raw);

  /// Lines each rule would split, in chip order.
  Map<String, int> get counts => {for (final d in kDelimiters) d.id: matchCount(lines, d)};

  DelimiterOption get rule {
    if (pickedRuleId != null) return kDelimiters.firstWhere((d) => d.id == pickedRuleId);
    final c = counts;
    return kDelimiters.reduce((best, d) => c[d.id]! > c[best.id]! ? d : best);
  }

  List<ParsedRow> get parsed => parsePastedText(raw, rule, swapColumns);
  List<ParsedRow> get unparsed => parsed.where((r) => !r.ok).toList();

  /// The rows "Add" will insert: every parsed line, plus unparsed ones
  /// fixed with both a role and a name.
  List<CastRow> get rows => [
        for (final r in parsed)
          if (r.ok)
            PairCastRow(role: r.left, actor: r.right)
          else if (_fixed(r) case (final role, final name))
            PairCastRow(role: role, actor: name),
      ];

  (String, String)? _fixed(ParsedRow r) {
    final fix = fixes[r.index];
    final role = (fix?.role ?? '').trim();
    final name = (fix?.name ?? r.left).trim();
    return role.isEmpty || name.isEmpty ? null : (role, name);
  }
}

/// Bulk entry (4.2): a live, rule-based splitter. No AI and no silent
/// corrections — anything a rule can't split is shown and fixed by hand.
class PasteController extends Notifier<PasteState> {
  @override
  PasteState build() => const PasteState();

  void setMode(PasteMode m) => state = state.copyWith(mode: m);

  /// New text invalidates fixes keyed by line number.
  void setRaw(String v) => state = PasteState(mode: state.mode, raw: v, pickedRuleId: state.pickedRuleId, swapColumns: state.swapColumns);

  void pickRule(String id) => state = state.copyWith(pickedRuleId: id);
  void toggleSwap() => state = state.copyWith(swapColumns: !state.swapColumns);

  void fixRole(int index, String v) => _fix(index, (f) => f.copyWith(role: v));
  void fixName(int index, String v) => _fix(index, (f) => f.copyWith(name: v));

  void _fix(int index, PasteFix Function(PasteFix) fn) =>
      state = state.copyWith(fixes: {...state.fixes, index: fn(state.fixes[index] ?? const PasteFix())});

  /// Where "Add" puts the rows: the focused cast or crew list, else the
  /// first in the document, else a new cast block after the focus.
  PairListBlock? get target {
    final blocks = ref.read(projectControllerProvider).blocks;
    final focused = ref.read(editorUiControllerProvider).focusedId;
    final pairs = blocks.whereType<PairListBlock>();
    return pairs.where((b) => b.id == focused).firstOrNull ?? pairs.firstOrNull;
  }

  /// Adds the rows in one undo step and returns how many were added.
  int apply() {
    final rows = state.rows;
    if (rows.isEmpty) return 0;
    final project = ref.read(projectControllerProvider.notifier);
    final into = target;
    if (into != null) {
      project.appendCastRows(into.id, rows);
    } else {
      final block = PairListBlock(id: newBlockId(), rows: rows);
      project.insertBlock(block, afterId: ref.read(editorUiControllerProvider).focusedId);
      ref.read(editorUiControllerProvider.notifier).focus(block.id);
    }
    return rows.length;
  }
}

/// Auto-disposed, so each opening of the sheet starts empty.
final pasteControllerProvider = NotifierProvider.autoDispose<PasteController, PasteState>(PasteController.new);
