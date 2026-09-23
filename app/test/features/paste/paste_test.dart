import 'package:endcrawl/domain/models/credit_block.dart';
import 'package:endcrawl/features/paste/controllers/paste_controller.dart';
import 'package:endcrawl/features/paste/models/paste_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rules', () {
    test('each rule counts the lines it would split', () {
      final lines = pastedLines('Renny — Sofia\nMarcus, Idris\n\nVance as Helen\n  ');
      final counts = {for (final d in kDelimiters) d.id: matchCount(lines, d)};
      expect(lines, hasLength(3));
      expect(counts, {'dash': 1, 'comma': 1, 'tab': 0, 'as': 1, 'spaces': 0});
    });

    test('a line without the rule is flagged, never guessed', () {
      final rows = parsePastedText('Renny — Sofia Alvarez\nNkechi Obi', kDelimiters.first, false);
      expect(rows.first.ok, isTrue);
      expect((rows.first.left, rows.first.right), ('Renny', 'Sofia Alvarez'));
      expect(rows.last.ok, isFalse);
      expect(rows.last.left, 'Nkechi Obi');
    });

    test('swap puts the name first', () {
      final row = parsePastedText('Sofia Alvarez — Renny', kDelimiters.first, true).single;
      expect((row.left, row.right), ('Renny', 'Sofia Alvarez'));
    });
  });

  group('PasteState', () {
    test('picks the rule that splits the most lines until one is chosen', () {
      const state = PasteState(raw: 'A, B\nC, D\nE — F');
      expect(state.rule.id, 'comma');
      expect(state.copyWith(pickedRuleId: 'dash').rule.id, 'dash');
    });

    test('an unparsed line counts once it has both a role and a name', () {
      const state = PasteState(raw: 'Renny — Sofia\nNkechi Obi');
      expect(state.rows, hasLength(1));

      final fixed = state.copyWith(fixes: {1: const PasteFix(role: 'Bartender')});
      expect(fixed.rows, hasLength(2));
      final added = fixed.rows.last as PairCastRow;
      expect((added.role, added.actor), ('Bartender', 'Nkechi Obi'));
    });
  });
}
