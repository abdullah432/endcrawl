import 'dart:convert';

import 'package:endcrawl/data/repositories/template_repository.dart';
import 'package:endcrawl/domain/models/block_catalog.dart';
import 'package:endcrawl/domain/models/credit_block.dart';
import 'package:flutter_test/flutter_test.dart';

CreditBlock _roundTrip(CreditBlock block) =>
    creditBlockFromJson((jsonDecode(jsonEncode(block.toJson())) as Map).cast<String, Object?>());

void main() {
  test('the catalogue has the design’s 27 kinds in seven groups, with unique codes and wire names', () {
    expect(BlockKind.values, hasLength(27));
    expect(BlockKind.values.map((k) => k.group).toSet(), hasLength(7));
    expect(BlockKind.values.map((k) => k.code).toSet(), hasLength(27));
    expect(BlockKind.values.map((k) => k.wire).toSet(), hasLength(27));
  });

  test('group sizes match the add-block library (4.1)', () {
    int count(BlockGroup g) => BlockKind.values.where((k) => k.group == g).length;
    expect(count(BlockGroup.openers), 4);
    expect(count(BlockGroup.people), 6);
    expect(count(BlockGroup.music), 2);
    expect(count(BlockGroup.logos), 3);
    expect(count(BlockGroup.text), 5);
    expect(count(BlockGroup.legal), 3);
    expect(count(BlockGroup.layout), 4);
  });

  for (final kind in BlockKind.values) {
    test('${kind.code} — a new block keeps its kind and content through storage', () {
      final block = newBlockOf(kind);
      final back = _roundTrip(block);

      expect(back.kind, kind);
      expect(back.id, block.id);
      expect(back.toJson(), block.toJson());
      expect(describeBlock(back).title, isNotEmpty);
    });
  }

  group('documents written before v2 still read', () {
    test('"dept" is a department name list', () {
      final b = creditBlockFromJson(const {'type': 'dept', 'id': 'b1', 'header': 'EDITED BY', 'names': ['Sam Oduya']});
      expect(b, isA<NameListBlock>().having((b) => b.kind, 'kind', BlockKind.department));
      expect((b as NameListBlock).names, ['Sam Oduya']);
    });

    test('"thanks" is a special-thanks name list', () {
      final b = creditBlockFromJson(const {'type': 'thanks', 'id': 'b1', 'names': ['A']});
      expect(b.kind, BlockKind.thanks);
      expect((b as NameListBlock).header, 'SPECIAL THANKS');
    });

    test('"cast" is a two-column pair list', () {
      final b = creditBlockFromJson(const {
        'type': 'cast',
        'id': 'b1',
        'rows': [
          {'type': 'pair', 'role': 'Renny', 'actor': 'Sofia Alvarez'},
        ],
      });
      expect(b.kind, BlockKind.castTwoColumn);
    });

    test('"logos" keeps its marks, which v1 stored under "logos"', () {
      final b = creditBlockFromJson(const {'type': 'logos', 'id': 'b1', 'logos': ['NORTHLIGHT']});
      expect((b as MarkBlock).marks, ['NORTHLIGHT']);
      expect(b.toJson()['marks'], ['NORTHLIGHT']);
    });
  });

  test('duplicating a block keeps its content under a new id', () {
    final block = newBlockOf(BlockKind.castTwoColumn);
    final copy = block.withId('bnew');
    expect(copy.id, 'bnew');
    expect((copy.toJson()..remove('id')), (block.toJson()..remove('id')));
  });

  test('stacked cast always renders stacked', () {
    final stacked = newBlockOf(BlockKind.castStacked) as PairListBlock;
    final twoColumn = newBlockOf(BlockKind.castTwoColumn) as PairListBlock;
    expect(stacked.alwaysStacked, isTrue);
    expect(twoColumn.alwaysStacked, isFalse);
  });

  group('block descriptions', () {
    test('a department reads as its header and a name count', () {
      final d = describeBlock(const NameListBlock(id: 'b', header: 'DIRECTED BY', names: ['Maya Okonkwo']));
      expect(d.title, 'Directed by');
      expect(d.detail, '1 name');
    });

    test('a cast list reads as rows, leaders and gutter', () {
      final d = describeBlock(const PairListBlock(id: 'b', gutter: 0.08, rows: [PairCastRow(), PairCastRow(), GapCastRow()]));
      expect(d.detail, '2 rows · dot leaders · gutter 8%');
    });

    test('special thanks reads its columns', () {
      final d = describeBlock(const NameListBlock(id: 'b', kind: BlockKind.thanks, header: 'Special thanks', names: ['A', 'B'], columns: 3));
      expect(d.detail, '2 names · 3 columns');
    });
  });

  group('templates', () {
    const repo = TemplateRepository();

    test('every template section builds blocks of its own kind', () {
      for (final t in kProjectTemplates) {
        for (final section in repo.sections(t.id)) {
          final blocks = section.build();
          expect(blocks, isNotEmpty, reason: '${t.id}/${section.id}');
          expect(blocks.map((b) => b.kind).toSet(), {section.kind}, reason: '${t.id}/${section.id}');
        }
      }
    });

    test('unticked sections are left out, and section ids are unique', () {
      for (final t in kProjectTemplates) {
        final ids = repo.sections(t.id).map((s) => s.id);
        expect(ids.toSet(), hasLength(ids.length), reason: t.id);
      }
      final withoutCast = repo.blocksFor('feature', include: {'title', 'directed'});
      expect(withoutCast.map((b) => b.kind), [BlockKind.title, BlockKind.directedBy]);
    });

    test('building twice gives fresh ids', () {
      final a = repo.seed('short').map((b) => b.id).toSet();
      final b = repo.seed('short').map((b) => b.id).toSet();
      expect(a.intersection(b), isEmpty);
    });
  });
}
