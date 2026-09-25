import 'dart:convert';

import 'package:lastreel/domain/models/credit_block.dart';
import 'package:lastreel/domain/models/credit_face.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/domain/models/project.dart';
import 'package:lastreel/domain/models/render_summary.dart';
import 'package:lastreel/domain/models/project_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// A project exercising every block type, every cast row kind, and
/// non-default settings — if this survives a round trip, the schema covers
/// everything the editor can produce.
Project _fullProject() {
  return Project(
    id: 'Abc123XyzAbc123XyzQq',
    title: 'THE LONG WAY DOWN',
    ownerId: 'user-1',
    settings: const ProjectSettings(
      formatId: 'custom',
      customW: 1998,
      customH: 1080,
      fps: 23.976,
      mode: TimingMode.speed,
      durationFrames: 2500,
      ppf: 4,
      headSeconds: 1.5,
      tailSeconds: 4.5,
      look: RollLook.crawl3d,
      tilt: 31,
      vanishingDistance: 95,
      background: MonitorBackground.alpha,
      face: CreditFace.condensed,
      safeGuides: false,
    ),
    blocks: const [
      TitleBlock(id: 'b1', banner: 'OYELARAN PICTURES', title: 'THE LONG WAY DOWN', byline: 'A FILM BY', titleScale: 2.8),
      NameListBlock(id: 'b2', header: 'DIRECTED BY', names: ['Mara Oyelaran']),
      PairListBlock(
        id: 'b3',
        header: 'CAST',
        leader: LeaderStyle.rule,
        gutter: 0.09,
        collapse: CastCollapseMode.always,
        rows: [
          PairCastRow(role: 'ELENA MARSH', actor: 'Priya Raghunathan'),
          GapCastRow(),
          SpanCastRow(text: 'and'),
        ],
      ),
      SongBlock(id: 'b4', songTitle: '"HOLLOW GROUND"', artist: 'THE PALE RIVER', courtesy: 'Courtesy of Norlight'),
      MarkBlock(id: 'b5', marks: ['SCREEN AUSTRALIA', 'NORLIGHT']),
      NameListBlock(id: 'b6', kind: BlockKind.thanks, header: 'SPECIAL THANKS', names: ['Annika Sørensen', 'Devlin O’Rourke']),
      HoldBlock(id: 'b7', lines: ['IN LOVING MEMORY'], hold: 4, fadeIn: 1.25, fadeOut: 0.75, muted: true),
      SpacerBlock(id: 'b8', seconds: 2.25),
    ],
    createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    updatedAt: DateTime.utc(2026, 2, 3, 4, 5, 6),
  );
}

void main() {
  group('Project serialization', () {
    test('survives a round trip through JSON text', () {
      final original = _fullProject();

      // Through a real encode/decode, not just the maps — this is what
      // actually hits disk, and it catches anything not JSON-encodable.
      final restored = Project.fromJson(
        (jsonDecode(jsonEncode(original.toJson())) as Map).cast<String, Object?>(),
      );

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.ownerId, original.ownerId);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
      expect(restored.schemaVersion, Project.currentSchemaVersion);

      final s = restored.settings;
      final o = original.settings;
      expect(s.formatId, o.formatId);
      expect(s.customW, o.customW);
      expect(s.customH, o.customH);
      expect(s.fps, o.fps);
      expect(s.mode, o.mode);
      expect(s.durationFrames, o.durationFrames);
      expect(s.ppf, o.ppf);
      expect(s.headSeconds, o.headSeconds);
      expect(s.tailSeconds, o.tailSeconds);
      expect(s.look, o.look);
      expect(s.tilt, o.tilt);
      expect(s.vanishingDistance, o.vanishingDistance);
      expect(s.background, o.background);
      expect(s.face, o.face);
      expect(s.safeGuides, o.safeGuides);

      expect(restored.blocks.map((b) => b.runtimeType).toList(),
          original.blocks.map((b) => b.runtimeType).toList());
      expect(restored.blocks.map((b) => b.id).toList(), original.blocks.map((b) => b.id).toList());
    });

    test('preserves every field of each block type', () {
      final restored = Project.fromJson(
        (jsonDecode(jsonEncode(_fullProject().toJson())) as Map).cast<String, Object?>(),
      );

      final title = restored.blocks[0] as TitleBlock;
      expect(title.banner, 'OYELARAN PICTURES');
      expect(title.byline, 'A FILM BY');
      expect(title.titleScale, 2.8);

      final dept = restored.blocks[1] as NameListBlock;
      expect(dept.header, 'DIRECTED BY');
      expect(dept.names, ['Mara Oyelaran']);

      final cast = restored.blocks[2] as PairListBlock;
      expect(cast.leader, LeaderStyle.rule);
      expect(cast.gutter, 0.09);
      expect(cast.collapse, CastCollapseMode.always);
      expect(cast.rows, hasLength(3));
      expect((cast.rows[0] as PairCastRow).role, 'ELENA MARSH');
      expect((cast.rows[0] as PairCastRow).actor, 'Priya Raghunathan');
      expect(cast.rows[1], isA<GapCastRow>());
      expect((cast.rows[2] as SpanCastRow).text, 'and');

      final song = restored.blocks[3] as SongBlock;
      expect(song.songTitle, '"HOLLOW GROUND"');
      expect(song.courtesy, 'Courtesy of Norlight');

      expect((restored.blocks[4] as MarkBlock).marks, ['SCREEN AUSTRALIA', 'NORLIGHT']);
      expect((restored.blocks[5] as NameListBlock).names, ['Annika Sørensen', 'Devlin O’Rourke']);

      final hold = restored.blocks[6] as HoldBlock;
      expect(hold.lines, ['IN LOVING MEMORY']);
      expect(hold.hold, 4);
      expect(hold.fadeIn, 1.25);
      expect(hold.fadeOut, 0.75);
      expect(hold.muted, isTrue);

      expect((restored.blocks[7] as SpacerBlock).seconds, 2.25);
    });

    test('writes enums by name, so reordering an enum cannot reinterpret stored data', () {
      final json = _fullProject().toJson();
      final settings = json['settings']! as Map<String, Object?>;

      expect(settings['mode'], 'speed');
      expect(settings['look'], 'crawl3d');
      expect(settings['background'], 'alpha');
      expect(settings['face'], 'condensed');

      final cast = (json['blocks']! as List)[2] as Map<String, Object?>;
      expect(cast['leader'], 'rule');
      expect(cast['collapse'], 'always');
      expect(cast['type'], 'cast');
    });

    test('reads a whole-number double back as a double', () {
      // JSON encodes 24.0 as `24`, which decodes as int — a naive
      // `as double` cast would throw on every project saved at 24 fps.
      final decoded = jsonDecode('{"fps":24,"tilt":30}') as Map<String, Object?>;
      final settings = ProjectSettings.fromJson(decoded);

      expect(settings.fps, 24.0);
      expect(settings.tilt, 30.0);
    });

    test('falls back to defaults for missing or unreadable fields', () {
      final settings = ProjectSettings.fromJson(const {'fps': 'not a number', 'look': 'hologram'});

      expect(settings.fps, const ProjectSettings().fps);
      // An unknown enum value from a newer build degrades instead of throwing.
      expect(settings.look, RollLook.flat2d);
    });

    test('rejects a block type it does not understand instead of dropping it', () {
      expect(
        () => creditBlockFromJson(const {'type': 'hologram', 'id': 'b9'}),
        throwsA(isA<UnknownDocumentTypeException>()),
      );
    });

    test('rejects a document from a newer schema version', () {
      final json = _fullProject().toJson();
      json['schemaVersion'] = Project.currentSchemaVersion + 1;

      expect(() => Project.fromJson(json), throwsA(isA<UnsupportedSchemaVersionException>()));
    });

    test('does not persist fontMissing, which is a per-device runtime condition', () {
      const block = TitleBlock(id: 'b1', title: 'X', fontMissing: true);

      expect(block.toJson().containsKey('fontMissing'), isFalse);
      expect(TitleBlock.fromJson(block.toJson()).fontMissing, isFalse);
    });

    test('mints ids that are valid Firestore document ids', () {
      final id = newProjectId();

      expect(id, hasLength(20));
      expect(RegExp(r'^[A-Za-z0-9]{20}$').hasMatch(id), isTrue);
    });

    test('touch() advances updatedAt without disturbing createdAt', () {
      final project = _fullProject();
      final touched = project.touch(now: DateTime.utc(2026, 6, 1));

      expect(touched.createdAt, project.createdAt);
      expect(touched.updatedAt, DateTime.utc(2026, 6, 1));
    });

    test('drops sub-millisecond precision, so a round-trip compares equal', () {
      // Firestore Timestamps and epoch-millis JSON both truncate; without
      // normalising, an in-memory project and the same project read back
      // would differ by a few hundred microseconds.
      final project = Project.create(now: DateTime.utc(2026, 6, 1, 12, 0, 0, 123, 456));

      expect(project.createdAt.microsecond, 0);
      expect(project.createdAt.millisecond, 123);
      expect(Project.fromJson(project.toJson()).createdAt, project.createdAt);
    });
  });

  group('sanitizeProjectTitle', () {
    test('trims, and rejects a title with nothing usable left', () {
      expect(sanitizeProjectTitle('  THE LONG WAY DOWN  '), 'THE LONG WAY DOWN');
      expect(sanitizeProjectTitle('   '), isNull);
      expect(sanitizeProjectTitle(''), isNull);
    });

    test('clamps to the same cap the security rules enforce', () {
      // A title the rules would reject has to be caught here, or the save
      // comes back as an opaque permission-denied from the server.
      final long = 'A' * (Project.maxTitleLength + 50);

      expect(sanitizeProjectTitle(long), hasLength(Project.maxTitleLength));
    });
  });

  group('schema v2', () {
    test('a v1 document reads with no last render, and is written back as v2', () {
      final v1 = _fullProject().toJson()
        ..['schemaVersion'] = 1
        ..remove('lastRender');

      final loaded = Project.fromJson(v1);

      expect(loaded.lastRender, isNull);
      expect(loaded.toJson()['schemaVersion'], 2);
    });

    test('the last render round-trips', () {
      final at = DateTime.utc(2026, 9, 20, 10);
      final project = _fullProject().copyWith(
        lastRender: RenderSummary(outcome: RenderOutcome.failed, codec: 'H.264', width: 1920, height: 1080, at: at),
      );

      final back = Project.fromJson(project.toJson()).lastRender!;

      expect(back.outcome, RenderOutcome.failed);
      expect(back.codec, 'H.264');
      expect(back.at, at);
    });

    test('a title stored before the 60-character cap is clamped on load', () {
      final json = _fullProject().toJson()..['title'] = 'T' * 120;
      expect(Project.fromJson(json).title, hasLength(60));
    });

    test('the library preview is the first card with names', () {
      final project = Project.create(blocks: const [
        TitleBlock(id: 't', title: 'THE LONG WAY DOWN'),
        NameListBlock(id: 'd', header: 'Directed by', names: ['Maya Okonkwo']),
      ]);

      expect(project.summary.preview.header, 'Directed by');
      expect(project.summary.preview.names, ['Maya Okonkwo']);
    });
  });

  group('entitlement', () {
    test('free keeps three projects and shows ads', () {
      const free = Entitlement.free();
      expect(free.canAddProject(2), isTrue);
      expect(free.canAddProject(3), isFalse);
      expect(free.slotsLeft(2), 1);
      expect(free.showsAds, isTrue);
    });

    test('pro is unlimited and ad-free', () {
      const pro = Entitlement.pro(period: BillingPeriod.yearly);
      expect(pro.canAddProject(300), isTrue);
      expect(pro.slotsLeft(300), isNull);
      expect(pro.showsAds, isFalse);
    });
  });

  group('monitor background', () {
    test('v1 backgrounds map onto the v2 set', () {
      expect(ProjectSettings.fromJson(const {'background': 'underlay'}).background, MonitorBackground.reference);
      expect(ProjectSettings.fromJson(const {'background': 'green'}).background, MonitorBackground.black);
      expect(ProjectSettings.fromJson(const {'background': 'custom'}).background, MonitorBackground.black);
      expect(ProjectSettings.fromJson(const {'background': 'paper'}).background, MonitorBackground.paper);
      expect(ProjectSettings.fromJson(const {}).background, MonitorBackground.black);
    });
  });
}
