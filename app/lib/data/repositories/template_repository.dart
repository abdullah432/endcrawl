import '../../domain/models/credit_block.dart';

/// Block constructors and starting-template seed data — a straight port of
/// the prototype's `mk*()` helpers and `seed(kind)`. Kept as a repository
/// because it's the "content source" the templates feature reads from,
/// not app state.
class TemplateRepository {
  const TemplateRepository();

  TitleBlock mkTitle() => TitleBlock(
        id: newBlockId(),
        banner: 'OYELARAN PICTURES',
        title: 'THE LONG WAY DOWN',
        byline: 'A FILM BY MARA OYELARAN',
        titleScale: 3.1,
      );

  DeptBlock mkDept(String header, List<String> names) =>
      DeptBlock(id: newBlockId(), header: header, names: names);

  CastBlock mkCast() => CastBlock(
        id: newBlockId(),
        header: 'CAST',
        leader: LeaderStyle.dots,
        gutter: 0.06,
        collapse: CastCollapseMode.auto,
        rows: const [
          PairCastRow(role: 'ELENA MARSH', actor: 'Priya Raghunathan'),
          PairCastRow(role: 'DET. AUGUST COLE', actor: 'Kwame Boateng'),
          PairCastRow(role: 'MARGO', actor: 'Hattie Lindqvist'),
          PairCastRow(role: 'YOUNG ELENA', actor: 'Sofia Navarro-Reyes'),
          PairCastRow(role: 'THE FERRYMAN', actor: 'Ibrahim Sesay'),
          PairCastRow(role: 'DR. HALVORSEN', actor: 'Greta Lindemann'),
          PairCastRow(role: 'BARTENDER', actor: 'Yusuf Demir'),
          PairCastRow(role: 'NIGHT NURSE', actor: 'Aoife Callaghan'),
          PairCastRow(role: 'TRANSIT COP', actor: 'Devon Marchetti'),
          PairCastRow(role: 'WOMAN ON PLATFORM', actor: 'Xiulan Ma'),
          GapCastRow(),
          SpanCastRow(text: 'and'),
          PairCastRow(role: 'JUNE MARSH', actor: 'Ruth Negeri'),
        ],
      );

  SongBlock mkSong() => SongBlock(
        id: newBlockId(),
        songTitle: '"HOLLOW GROUND"',
        artist: 'Written and performed by THE PALE RIVER',
        courtesy: 'Courtesy of Norlight Records',
      );

  ThanksBlock mkThanks() => ThanksBlock(
        id: newBlockId(),
        header: 'SPECIAL THANKS',
        names: const [
          'Annika Sørensen', 'Bartholomew Ng', 'Cassia Duarte', 'Devlin O’Rourke',
          'Emeka Nwachukwu', 'Farida Haddad', 'Gunnar Eklund', 'Hyun-woo Park',
          'Isabel Cardoso', 'Jonas Vikström', 'Keziah Mbeki', 'Lucia Ferrante',
          'Mikhail Petrov', 'Nadia Bouchard', 'Oskar Lindgren', 'Perrine Vasseur',
        ],
      );

  LogosBlock mkLogos() => LogosBlock(
        id: newBlockId(),
        logos: const ['SCREEN AUSTRALIA', 'NORLIGHT', 'HARBOUR POST', 'THE FILM FUND'],
      );

  HoldBlock mkHold(double holdSeconds, List<String> lines) =>
      HoldBlock(id: newBlockId(), lines: lines, hold: holdSeconds, fadeIn: 1, fadeOut: 1);

  SpacerBlock mkSpacer() => SpacerBlock(id: newBlockId(), seconds: 1.5);

  /// The blocks a template starts with.
  List<CreditBlock> seed(String templateId) {
    final t = mkTitle();
    return switch (templateId) {
      // Lean crew list, single column, one music cue.
      'short' => [
          t,
          mkDept('DIRECTED BY', ['Mara Oyelaran']),
          mkDept('WRITTEN BY', ['Mara Oyelaran']),
          mkDept('DIRECTOR OF PHOTOGRAPHY', ['Aurélie Banks']),
          mkDept('EDITED BY', ['Sam Oduya']),
          mkSong(),
          mkHold(4, ['© MMXXVI OYELARAN PICTURES', 'ALL RIGHTS RESERVED']),
        ],
      // Stacked pairs, larger type, caption-safe.
      'vertical' => [
          t,
          mkDept('WRITTEN & DIRECTED BY', ['Mara Oyelaran']),
          mkDept('EDITED BY', ['Sam Oduya']),
          mkSong(),
          mkThanks(),
          mkHold(3, ['THANKS FOR WATCHING']),
        ],
      // Department order, billing block, two-column cast.
      _ => [
          t,
          mkDept('DIRECTED BY', ['Mara Oyelaran']),
          mkDept('WRITTEN BY', ['Mara Oyelaran', 'Tobias Renn']),
          mkDept('PRODUCED BY', ['Ines Kovač', 'Daniel Whitfield']),
          mkCast(),
          mkDept('DIRECTOR OF PHOTOGRAPHY', ['Aurélie Banks']),
          mkDept('EDITED BY', ['Sam Oduya']),
          mkDept('PRODUCTION DESIGNER', ['Noor Haddad']),
          mkDept('MUSIC BY', ['Felix Arinze']),
          mkSong(),
          mkThanks(),
          mkLogos(),
          mkHold(4, ['IN LOVING MEMORY', 'JUNE WHITFIELD', '1948 — 2024']),
          mkHold(5, ['© MMXXVI OYELARAN PICTURES LLC', 'ALL RIGHTS RESERVED']),
        ],
    };
  }

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
/// and runtime, and — through [TemplateRepository.seed] — its blocks.
///
/// The "24 fps · 2.39:1 · 18 blocks" line is derived from these values and
/// the seed, never written by hand, so it can't drift from what the template
/// actually creates.
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
