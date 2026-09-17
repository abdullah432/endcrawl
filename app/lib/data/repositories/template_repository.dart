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

  List<CreditBlock> seed(String kind) {
    final t = mkTitle();
    if (kind == 'youtube') {
      return [
        t,
        mkDept('WRITTEN & DIRECTED BY', ['Mara Oyelaran']),
        mkDept('EDITED BY', ['Sam Oduya']),
        mkSong(),
        mkThanks(),
        mkHold(3, ['THANKS FOR WATCHING', 'SUBSCRIBE FOR MORE']),
      ];
    }
    if (kind == 'music') {
      return [
        t,
        mkDept('DIRECTED BY', ['Mara Oyelaran']),
        mkSong(),
        mkDept('PRODUCTION COMPANY', ['Harbour Post']),
        mkLogos(),
      ];
    }
    return [
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
    ];
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

class ProjectTemplate {
  final String id;
  final String name;
  final String description;
  final String meta;
  final String formatId;
  final double fps;
  final double durationSeconds;
  final String? projectName;

  const ProjectTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.meta,
    required this.formatId,
    required this.fps,
    required this.durationSeconds,
    this.projectName,
  });
}

const kProjectTemplates = <ProjectTemplate>[
  ProjectTemplate(
    id: 'short',
    name: 'Short Film',
    description: 'Title card, department stack, two-column cast, copyright hold.',
    meta: '2.39:1 · 24 fps · 01:44',
    formatId: '239',
    fps: 24,
    durationSeconds: 104,
  ),
  ProjectTemplate(
    id: 'feature',
    name: 'Feature',
    description: 'Full contractual order with billing block and studio logos.',
    meta: '2.39:1 · 24 fps · 06:00',
    formatId: '239',
    fps: 24,
    durationSeconds: 360,
  ),
  ProjectTemplate(
    id: 'youtube',
    name: 'YouTube',
    description: 'Vertical, fast, soundtrack credit and an end card.',
    meta: '9:16 · 30 fps · 00:22',
    formatId: '9x16',
    fps: 30,
    durationSeconds: 22,
    projectName: 'CHANNEL OUTRO',
  ),
  ProjectTemplate(
    id: 'music',
    name: 'Music Video',
    description: 'Compact crew roll under the last chorus.',
    meta: '16:9 · 25 fps · 00:40',
    formatId: '16x9',
    fps: 25,
    durationSeconds: 40,
  ),
  ProjectTemplate(
    id: 'student',
    name: 'Student Film',
    description: 'Teaches the standard card order as you fill it in.',
    meta: '16:9 · 24 fps · 01:20',
    formatId: '16x9',
    fps: 24,
    durationSeconds: 80,
  ),
];
