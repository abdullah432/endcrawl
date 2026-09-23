import 'credit_block.dart';

/// A new block of [kind], with placeholder content that shows what it's for.
///
/// Placeholder rather than empty: a block added from the library (4.1)
/// appears in the monitor straight away looking like what it is, and the
/// edit sheet opens on something to overwrite rather than a blank form.
CreditBlock newBlockOf(BlockKind kind, {String? id}) {
  final blockId = id ?? newBlockId();
  return switch (kind) {
    BlockKind.title => TitleBlock(id: blockId, title: 'FILM TITLE', byline: 'A FILM BY'),
    BlockKind.presents => CardBlock(id: blockId, kind: kind, lines: const ['A Northlight production']),
    BlockKind.directedBy => CardBlock(id: blockId, kind: kind, header: 'Directed by', lines: const ['Name']),
    BlockKind.scoreBy => CardBlock(id: blockId, kind: kind, header: 'Original score by', lines: const ['Name']),
    BlockKind.dedication => CardBlock(id: blockId, kind: kind, header: 'In memory of', lines: const ['Name']),
    BlockKind.quote => CardBlock(id: blockId, kind: kind, lines: const ['A line worth ending on.'], footer: 'Attribution'),
    BlockKind.freeText => CardBlock(id: blockId, kind: kind, lines: const ['Any paragraph of text.']),
    BlockKind.copyright => CardBlock(
        id: blockId,
        kind: kind,
        lines: ['© ${DateTime.now().year} Production company', 'All rights reserved'],
      ),
    BlockKind.disclaimer => CardBlock(
        id: blockId,
        kind: kind,
        lines: const [
          'The events, characters and firms depicted in this photoplay are fictitious. '
              'Any similarity to actual persons, living or dead, or to actual events or firms is purely coincidental.',
        ],
      ),
    BlockKind.sectionHeading => CardBlock(id: blockId, kind: kind, header: 'Second unit'),
    BlockKind.mainCredits => MainCreditsBlock(id: blockId, cards: const [
        CreditEntry(header: 'Casting by', names: ['Name']),
        CreditEntry(header: 'Edited by', names: ['Name']),
      ]),
    BlockKind.castTwoColumn ||
    BlockKind.castStacked =>
      PairListBlock(id: blockId, kind: kind, header: 'Cast', rows: const [PairCastRow(role: 'Role', actor: 'Name')]),
    BlockKind.crewTwoColumn =>
      PairListBlock(id: blockId, kind: kind, header: 'Crew', rows: const [PairCastRow(role: 'Job', actor: 'Name')]),
    BlockKind.department => NameListBlock(id: blockId, kind: kind, header: 'Department', names: const ['Name']),
    BlockKind.nameList => NameListBlock(id: blockId, kind: kind, header: 'Crew', names: const ['Name', 'Name']),
    BlockKind.stunts => NameListBlock(id: blockId, kind: kind, header: 'Stunts', names: const ['Coordinator']),
    BlockKind.thanks => NameListBlock(id: blockId, kind: kind, header: 'Special thanks', names: const ['Name']),
    BlockKind.locations => NameListBlock(id: blockId, kind: kind, header: 'Filmed on location in', names: const ['Place']),
    BlockKind.musicCue => SongBlock(id: blockId, songTitle: '"Song title"', artist: 'Written and performed by'),
    BlockKind.logoRow => MarkBlock(id: blockId, kind: kind, marks: const ['LOGO', 'LOGO']),
    BlockKind.singleLogo => MarkBlock(id: blockId, kind: kind, marks: const ['LOGO']),
    BlockKind.still => MarkBlock(id: blockId, kind: kind, marks: const ['STILL'], lines: const ['Caption']),
    BlockKind.guild => MarkBlock(id: blockId, kind: kind, marks: const ['GUILD'], lines: const ['Required line']),
    BlockKind.hold => HoldBlock(id: blockId, lines: const ['HOLD CARD']),
    BlockKind.spacer => SpacerBlock(id: blockId),
    BlockKind.divider => DividerBlock(id: blockId),
  };
}

/// How a block reads in the editor's list: a title ("Directed by", "Visual
/// effects") and a detail line ("1 name", "28 rows · dot leaders").
///
/// Domain rather than widget code so the list, template contents and any
/// future export summary describe a block the same way.
class BlockDescription {
  final String title;
  final String detail;
  const BlockDescription(this.title, this.detail);
}

BlockDescription describeBlock(CreditBlock block) {
  String nameCount(int n) => '$n ${n == 1 ? 'name' : 'names'}';
  String cols(int c) => c > 1 ? ' · $c columns' : '';
  String titled(String header) => header.trim().isEmpty ? block.kind.label : _sentence(header);

  return switch (block) {
    TitleBlock(:final title, :final byline) => BlockDescription(
        block.kind.label,
        [if (title.isNotEmpty) _sentence(title), if (byline.isNotEmpty) byline.toLowerCase()].join(' · '),
      ),
    CardBlock(:final header, :final lines, :final footer) => BlockDescription(
        block.kind == BlockKind.sectionHeading ? block.kind.label : titled(header),
        block.kind == BlockKind.sectionHeading
            ? _sentence(header)
            : [
                if (lines.isNotEmpty) lines.first,
                if (footer.isNotEmpty) '— $footer',
              ].join(' '),
      ),
    MainCreditsBlock(:final cards) => BlockDescription(block.kind.label, '${cards.length} ${cards.length == 1 ? 'card' : 'cards'}'),
    PairListBlock(:final rows, :final leader, :final gutter) => BlockDescription(
        block.kind.label,
        [
          '${rows.whereType<PairCastRow>().length} rows',
          if (block.kind != BlockKind.castStacked) ...[
            switch (leader) {
              LeaderStyle.dots => 'dot leaders',
              LeaderStyle.rule => 'rule leaders',
              LeaderStyle.clean => 'no leaders',
            },
            'gutter ${(gutter * 100).round()}%',
          ],
        ].join(' · '),
      ),
    NameListBlock(:final header, :final names, :final columns) =>
      BlockDescription(titled(header), '${nameCount(names.length)}${cols(columns)}'),
    SongBlock(:final songTitle, :final artist) =>
      BlockDescription(block.kind.label, [songTitle, artist].where((s) => s.isNotEmpty).join(' · ')),
    MarkBlock(:final marks) => BlockDescription(
        block.kind.label,
        '${marks.length} ${marks.length == 1 ? 'mark' : 'marks'}${block.kind == BlockKind.logoRow ? ' · one row' : ''}',
      ),
    HoldBlock(:final lines, :final hold) =>
      BlockDescription(block.kind.label, '${lines.isEmpty ? 'Empty' : lines.first} · holds ${_seconds(hold)}'),
    SpacerBlock(:final seconds) => BlockDescription(block.kind.label, _seconds(seconds)),
    DividerBlock(:final style) => BlockDescription(block.kind.label, style == DividerStyle.rule ? 'Thin rule' : 'Ornament'),
  };
}

/// "DIRECTOR OF PHOTOGRAPHY" → "Director of photography" for list titles;
/// mixed-case input is left as the person typed it.
String _sentence(String s) {
  final t = s.trim();
  if (t.isEmpty || t != t.toUpperCase()) return t;
  final lower = t.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

String _seconds(double s) => s == s.roundToDouble() ? '${s.round()}s' : '${s.toStringAsFixed(1)}s';
