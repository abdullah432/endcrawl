import 'package:endcrawl/domain/models/credit_block.dart';
import 'package:endcrawl/domain/models/project.dart';
import 'package:endcrawl/domain/models/project_settings.dart';

/// A small, fully known document: five blocks, one of each common shape.
Project film({TimingMode mode = TimingMode.speed, int durationFrames = 24 * 60}) {
  return Project.create(
    title: 'The Long Way Down',
    now: DateTime.utc(2026, 9, 20),
    settings: ProjectSettings(formatId: '16x9', fps: 24, mode: mode, durationFrames: durationFrames, ppf: 4),
    blocks: const [
      TitleBlock(id: 'ttl', title: 'THE LONG WAY DOWN', byline: 'A FILM BY'),
      NameListBlock(id: 'dir', header: 'Directed by', names: ['Maya Okonkwo']),
      PairListBlock(id: 'cst', header: 'Cast', rows: [
        PairCastRow(role: 'Renny', actor: 'Sofia Alvarez'),
        PairCastRow(role: 'Marcus', actor: 'Idris Oyelaran'),
      ]),
      SongBlock(id: 'sng', songTitle: '"Low Tide"', artist: 'Hana Bexley'),
      NameListBlock(id: 'thx', kind: BlockKind.thanks, header: 'Special thanks', names: ['A', 'B', 'C']),
    ],
  );
}
