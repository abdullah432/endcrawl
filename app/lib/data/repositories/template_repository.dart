import '../../domain/models/credit_block.dart';

/// One line of a template's contents (2.2): a kind of block, a label that
/// says how much of it there is ("Crew departments · 12"), whether it's
/// ticked by default, and the blocks it adds.
///
/// Sections rather than a flat block list because that's how people think
/// about a template — "do I want stunts?", not "do I want block 14" — and it
/// lets twelve department blocks be one choice.
class TemplateSection {
  final String id;
  final BlockKind kind;
  final String label;
  final bool includedByDefault;
  final List<CreditBlock> Function() build;

  const TemplateSection({
    required this.id,
    required this.kind,
    required this.label,
    required this.build,
    this.includedByDefault = true,
  });
}

/// Template content: the design's three templates, as sections of blocks.
/// Kept as a repository because it's the content source the new-project
/// flow reads from, not app state.
class TemplateRepository {
  const TemplateRepository();

  /// The sections of [templateId], in roll order.
  List<TemplateSection> sections(String templateId) => switch (templateId) {
        'short' => _short,
        'vertical' => _vertical,
        _ => _feature,
      };

  /// The blocks for the chosen sections (all defaults when [include] is
  /// null), each with a fresh id.
  List<CreditBlock> blocksFor(String templateId, {Set<String>? include}) => [
        for (final section in sections(templateId))
          if (include?.contains(section.id) ?? section.includedByDefault) ...section.build(),
      ];

  /// What a template creates when nothing is unticked.
  List<CreditBlock> seed(String templateId) => blocksFor(templateId);

  // ---- building blocks --------------------------------------------------

  static TitleBlock _title() => TitleBlock(
        id: newBlockId(),
        banner: 'NORTHLIGHT PICTURES',
        title: 'THE LONG WAY DOWN',
        byline: 'A FILM BY MAYA OKONKWO',
        titleScale: 3.1,
      );

  static CardBlock _card(BlockKind kind, String header, List<String> lines, {String footer = ''}) =>
      CardBlock(id: newBlockId(), kind: kind, header: header, lines: lines, footer: footer);

  static NameListBlock _names(BlockKind kind, String header, List<String> names, {int columns = 0}) =>
      NameListBlock(id: newBlockId(), kind: kind, header: header, names: names, columns: columns);

  static PairListBlock _cast(BlockKind kind) => PairListBlock(
        id: newBlockId(),
        kind: kind,
        header: 'Cast',
        rows: const [
          PairCastRow(role: 'Renny', actor: 'Sofia Alvarez'),
          PairCastRow(role: 'Marcus', actor: 'Idris Oyelaran'),
          PairCastRow(role: 'Dr. Vance', actor: 'Helen Tsai'),
          PairCastRow(role: 'Bartender', actor: 'Nkechi Obi'),
          PairCastRow(role: 'Detective', actor: 'Sam Whitfield'),
          PairCastRow(role: 'Nurse', actor: 'Lucia Ferrante'),
          PairCastRow(role: 'Taxi driver', actor: 'Omar Haddad'),
          GapCastRow(),
          SpanCastRow(text: 'and'),
          PairCastRow(role: 'Young Renny', actor: 'Cleo Barr'),
        ],
      );

  static SongBlock _song(String title, String artist) =>
      SongBlock(id: newBlockId(), songTitle: title, artist: artist, courtesy: 'Courtesy of Norlight Records');

  static const _departments = <(String, List<String>)>[
    ('Director of photography', ['Yusuf Karadeniz']),
    ('Editor', ['Bruno Takahashi']),
    ('Production design', ['Ingrid Sólveig']),
    ('Costume design', ['Aurélie Banks']),
    ('Sound', ['Kwabena Mensah', 'Rosalind Achterberg']),
    ('Hair & make-up', ['Tomás Iriarte']),
    ('Camera', ['Nadia Bellweather', 'Devon Marchetti']),
    ('Grip & electric', ['Gunnar Eklund', 'Hyun-woo Park']),
    ('Locations', ['Isabel Cardoso']),
    ('Art department', ['Jonas Vikström', 'Keziah Mbeki']),
    ('Visual effects', ['Lucia Ferrante', 'Mikhail Petrov', 'Nadia Bouchard']),
    ('Post-production', ['Oskar Lindgren']),
  ];

  static const _thanks = [
    'Annika Sørensen', 'Bartholomew Ng', 'Cassia Duarte', 'Devlin O’Rourke',
    'Emeka Nwachukwu', 'Farida Haddad', 'Gunnar Eklund', 'Hyun-woo Park',
    'Isabel Cardoso', 'Jonas Vikström', 'Keziah Mbeki', 'Lucia Ferrante',
  ];

  // ---- templates --------------------------------------------------------

  /// Department order, billing block, two-column cast.
  static final _feature = <TemplateSection>[
    TemplateSection(id: 'title', kind: BlockKind.title, label: 'Title card', build: () => [_title()]),
    TemplateSection(
      id: 'directed',
      kind: BlockKind.directedBy,
      label: 'Directed by',
      build: () => [_card(BlockKind.directedBy, 'Directed by', ['Maya Okonkwo'])],
    ),
    TemplateSection(
      id: 'main',
      kind: BlockKind.mainCredits,
      label: 'Main credits · 8 cards',
      build: () => [
        MainCreditsBlock(id: newBlockId(), cards: const [
          CreditEntry(header: 'Written by', names: ['Maya Okonkwo', 'Aron Petrakis']),
          CreditEntry(header: 'Produced by', names: ['Delia Whitmore']),
          CreditEntry(header: 'Casting by', names: ['Priya Raghunathan']),
          CreditEntry(header: 'Director of photography', names: ['Yusuf Karadeniz']),
          CreditEntry(header: 'Edited by', names: ['Bruno Takahashi']),
          CreditEntry(header: 'Production designer', names: ['Ingrid Sólveig']),
          CreditEntry(header: 'Costume designer', names: ['Aurélie Banks']),
          CreditEntry(header: 'Music by', names: ['Hana Bexley']),
        ]),
      ],
    ),
    TemplateSection(id: 'cast', kind: BlockKind.castTwoColumn, label: 'Cast · two column', build: () => [_cast(BlockKind.castTwoColumn)]),
    TemplateSection(
      id: 'crew',
      kind: BlockKind.department,
      label: 'Crew departments · ${_departments.length}',
      build: () => [for (final (h, n) in _departments) _names(BlockKind.department, h, n)],
    ),
    TemplateSection(
      id: 'stunts',
      kind: BlockKind.stunts,
      label: 'Stunts',
      includedByDefault: false,
      build: () => [_names(BlockKind.stunts, 'Stunts', ['Dario Menendez', 'Cleo Barr', 'Omar Haddad'])],
    ),
    TemplateSection(
      id: 'music',
      kind: BlockKind.musicCue,
      label: 'Music cues · 3',
      build: () => [
        _song('"Low Tide"', 'Written and performed by Hana Bexley'),
        _song('"Salt Flats"', 'Performed by The Pale River'),
        _song('"Long Way Down"', 'Written by Hana Bexley'),
      ],
    ),
    TemplateSection(
      id: 'thanks',
      kind: BlockKind.thanks,
      label: 'Special thanks',
      build: () => [_names(BlockKind.thanks, 'Special thanks', _thanks, columns: 3)],
    ),
    TemplateSection(
      id: 'locations',
      kind: BlockKind.locations,
      label: 'Filming locations',
      includedByDefault: false,
      build: () => [_names(BlockKind.locations, 'Filmed on location in', ['Reykjavík, Iceland', 'Lisbon, Portugal'])],
    ),
    TemplateSection(
      id: 'dedication',
      kind: BlockKind.dedication,
      label: 'Dedication',
      includedByDefault: false,
      build: () => [_card(BlockKind.dedication, 'In loving memory of', ['June Whitfield', '1948 — 2024'])],
    ),
    TemplateSection(
      id: 'score',
      kind: BlockKind.scoreBy,
      label: 'Score by',
      build: () => [_card(BlockKind.scoreBy, 'Original score by', ['Hana Bexley'])],
    ),
    TemplateSection(
      id: 'second-unit',
      kind: BlockKind.sectionHeading,
      label: 'Second unit heading',
      build: () => [_card(BlockKind.sectionHeading, 'Second unit', const [])],
    ),
    TemplateSection(
      id: 'second-unit-crew',
      kind: BlockKind.nameList,
      label: 'Second unit crew',
      build: () => [
        _names(BlockKind.nameList, 'Second unit', ['Farida Haddad', 'Emeka Nwachukwu', 'Cassia Duarte', 'Bartholomew Ng'], columns: 2),
      ],
    ),
    TemplateSection(
      id: 'logos',
      kind: BlockKind.logoRow,
      label: 'Logo row',
      build: () => [MarkBlock(id: newBlockId(), marks: const ['NORTHLIGHT', 'HARBOUR POST', 'THE FILM FUND'])],
    ),
    TemplateSection(
      id: 'guild',
      kind: BlockKind.guild,
      label: 'Guild & union marks',
      build: () => [
        MarkBlock(id: newBlockId(), kind: BlockKind.guild, marks: const ['SAG-AFTRA'], lines: const ['Produced under a SAG-AFTRA agreement']),
      ],
    ),
    TemplateSection(
      id: 'disclaimer',
      kind: BlockKind.disclaimer,
      label: 'Disclaimer',
      build: () => [
        _card(BlockKind.disclaimer, '', const [
          'The events, characters and firms depicted in this photoplay are fictitious. '
              'Any similarity to actual persons, living or dead, or to actual events or firms is purely coincidental.',
        ]),
      ],
    ),
    TemplateSection(
      id: 'copyright',
      kind: BlockKind.copyright,
      label: 'Copyright notice',
      build: () => [_card(BlockKind.copyright, '', const ['© MMXXVI Northlight Pictures LLC', 'All rights reserved'])],
    ),
    TemplateSection(
      id: 'end-card',
      kind: BlockKind.hold,
      label: 'End card hold',
      build: () => [HoldBlock(id: newBlockId(), lines: const ['THE LONG WAY DOWN'], hold: 4)],
    ),
  ];

  /// Lean crew list, single column, one music cue.
  static final _short = <TemplateSection>[
    TemplateSection(id: 'title', kind: BlockKind.title, label: 'Title card', build: () => [_title()]),
    TemplateSection(
      id: 'directed',
      kind: BlockKind.directedBy,
      label: 'Directed by',
      build: () => [_card(BlockKind.directedBy, 'Written & directed by', ['Maya Okonkwo'])],
    ),
    TemplateSection(id: 'cast', kind: BlockKind.castStacked, label: 'Cast · stacked', build: () => [_cast(BlockKind.castStacked)]),
    TemplateSection(
      id: 'crew',
      kind: BlockKind.nameList,
      label: 'Crew list',
      build: () => [
        _names(BlockKind.nameList, 'Crew', ['Yusuf Karadeniz', 'Bruno Takahashi', 'Ingrid Sólveig', 'Kwabena Mensah'], columns: 1),
      ],
    ),
    TemplateSection(
      id: 'music',
      kind: BlockKind.musicCue,
      label: 'Music cue',
      build: () => [_song('"Low Tide"', 'Written and performed by Hana Bexley')],
    ),
    TemplateSection(
      id: 'thanks',
      kind: BlockKind.thanks,
      label: 'Special thanks',
      build: () => [_names(BlockKind.thanks, 'Special thanks', _thanks.take(6).toList(), columns: 2)],
    ),
    TemplateSection(
      id: 'copyright',
      kind: BlockKind.copyright,
      label: 'Copyright notice',
      build: () => [_card(BlockKind.copyright, '', const ['© MMXXVI Maya Okonkwo', 'All rights reserved'])],
    ),
  ];

  /// Stacked pairs, larger type, caption-safe.
  static final _vertical = <TemplateSection>[
    TemplateSection(id: 'title', kind: BlockKind.title, label: 'Title card', build: () => [_title()]),
    TemplateSection(id: 'cast', kind: BlockKind.castStacked, label: 'Cast · stacked', build: () => [_cast(BlockKind.castStacked)]),
    TemplateSection(
      id: 'crew',
      kind: BlockKind.department,
      label: 'Made by',
      build: () => [_names(BlockKind.department, 'Made by', ['Maya Okonkwo', 'Bruno Takahashi'])],
    ),
    TemplateSection(
      id: 'music',
      kind: BlockKind.musicCue,
      label: 'Music cue',
      build: () => [_song('"Low Tide"', 'Hana Bexley')],
    ),
    TemplateSection(
      id: 'thanks',
      kind: BlockKind.thanks,
      label: 'Special thanks',
      build: () => [_names(BlockKind.thanks, 'Thanks to', _thanks.take(4).toList(), columns: 1)],
    ),
    TemplateSection(
      id: 'end-card',
      kind: BlockKind.hold,
      label: 'End card',
      build: () => [HoldBlock(id: newBlockId(), lines: const ['THANKS FOR WATCHING'], hold: 3)],
    ),
  ];

  static const standardDepartmentOrder = [
    'DIRECTED BY',
    'WRITTEN BY',
    'PRODUCED BY',
    'EXECUTIVE PRODUCER',
    'DIRECTOR OF PHOTOGRAPHY',
    'EDITED BY',
    'PRODUCTION DESIGNER',
    'COSTUME DESIGNER',
    'MUSIC BY',
    'CASTING BY',
  ];
}

/// A starting point for a new project (1.2 / 2.1): its format, frame rate
/// and runtime, and — through [TemplateRepository.sections] — its blocks.
///
/// The "24 fps · 2.39:1 · 28 blocks" line is derived from these values and
/// the sections, never written by hand, so it can't drift from what the
/// template actually creates.
class ProjectTemplate {
  final String id;
  final String name;
  final String description;
  final String formatId;
  final double fps;
  final double durationSeconds;

  /// The default title for a project started from this template.
  final String defaultTitle;

  const ProjectTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.formatId,
    required this.fps,
    required this.durationSeconds,
    required this.defaultTitle,
  });
}

const kProjectTemplates = <ProjectTemplate>[
  ProjectTemplate(
    id: 'feature',
    name: 'Feature film',
    description: 'Department order, billing block, two-column cast.',
    formatId: '239',
    fps: 24,
    durationSeconds: 161,
    defaultTitle: 'Untitled feature',
  ),
  ProjectTemplate(
    id: 'short',
    name: 'Short film',
    description: 'Lean crew list, single column, one music cue.',
    formatId: '16x9',
    fps: 24,
    durationSeconds: 60,
    defaultTitle: 'Untitled short',
  ),
  ProjectTemplate(
    id: 'vertical',
    name: 'Vertical social cut',
    description: 'Stacked pairs, larger type, caption-safe.',
    formatId: '9x16',
    fps: 30,
    durationSeconds: 22,
    defaultTitle: 'Untitled vertical',
  ),
];
