import 'package:endcrawl/domain/models/credit_block.dart';
import 'package:endcrawl/domain/models/project_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  late AppHarness app;

  setUp(() => app = AppHarness(projects: FakeProjectRepository(seed: [film()])));

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Library → the seeded project's card → the editor.
  Future<void> openEditor(WidgetTester tester) async {
    await app.pump(tester);
    await tester.tap(find.text('The Long Way Down'));
    await tester.pumpAndSettle();
  }

  List<String> blockIds() => app.projects.projects.values.single.blocks.map((b) => b.id).toList();

  /// Saves are debounced; let the timer run.
  Future<void> flushAutosave(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  group('3.1 editor', () {
    testWidgets('shows the project, its status line, its blocks and the dock', (tester) async {
      await openEditor(tester);

      expect(find.text('The Long Way Down'), findsOneWidget);
      expect(find.textContaining('24 fps · '), findsOneWidget);
      expect(find.textContaining('4 px/frame · clean'), findsOneWidget);
      expect(find.text('5 BLOCKS'), findsOneWidget);
      expect(find.text('Directed by'), findsWidgets);
      for (final action in ['Block', 'Paste', 'Timing', 'Export']) {
        expect(find.text(action), findsOneWidget);
      }
    });

    testWidgets('opening marks the project open; leaving clears the mark', (tester) async {
      await openEditor(tester);
      final id = app.projects.projects.keys.single;
      expect((await app.session.read()).leftOpenProjectId, id);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      final stored = await app.session.read();
      expect(stored.leftOpenProjectId, isNull);
      expect(stored.lastOpenedProjectId, id);
    });

    testWidgets('an edit is autosaved without any explicit save action', (tester) async {
      await openEditor(tester);
      final before = app.projects.saveCount;

      await tapText(tester, '2D');
      await tapText(tester, '3D crawl');
      expect(app.projects.saveCount, before, reason: 'debounced');

      await flushAutosave(tester);
      expect(app.projects.projects.values.single.settings.look, RollLook.crawl3d);
    });

    testWidgets('undo and redo step through block edits', (tester) async {
      await openEditor(tester);
      expect(find.byTooltip('Undo'), findsOneWidget);

      await tester.drag(find.text('Music cue'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Music cue'), findsNothing);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Music cue'), findsOneWidget);

      await tester.tap(find.byTooltip('Redo'));
      await tester.pumpAndSettle();
      expect(find.text('Music cue'), findsNothing);
    });
  });

  group('3.2 readability warning', () {
    testWidgets('a fractional rate states the runtime and cause, with fixes and Ignore', (tester) async {
      app = AppHarness(projects: FakeProjectRepository(seed: [film(mode: TimingMode.duration, durationFrames: 24 * 47 + 5)]));
      await openEditor(tester);

      expect(find.textContaining('will judder.', findRichText: true), findsOneWidget);
      expect(find.textContaining('px/frame is fractional', findRichText: true), findsOneWidget);
      expect(find.textContaining(RegExp(r'px/f$')), findsWidgets);

      await tapText(tester, 'Ignore');
      expect(find.textContaining('will judder.', findRichText: true), findsNothing);
    });

    testWidgets('a fix locks a whole-pixel speed and clears the warning', (tester) async {
      app = AppHarness(projects: FakeProjectRepository(seed: [film(mode: TimingMode.duration, durationFrames: 24 * 47 + 5)]));
      await openEditor(tester);

      await tester.tap(find.textContaining(RegExp(r'px/f$')).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('will judder.', findRichText: true), findsNothing);
      await flushAutosave(tester);
      final settings = app.projects.projects.values.single.settings;
      expect(settings.mode, TimingMode.speed);
      expect(settings.ppf, settings.ppf.roundToDouble());
    });
  });

  group('3.3 multi-select', () {
    testWidgets('Select swaps the dock for the bulk bar and counts the selection', (tester) async {
      await openEditor(tester);

      await tapText(tester, 'Select');
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Export'), findsNothing);
      expect(find.byTooltip('Drag to reorder'), findsNothing);

      await tapText(tester, 'Directed by');
      await tapText(tester, 'Music cue');

      expect(find.text('2 OF 5 SELECTED'), findsOneWidget);
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('Mute mutes the selection, then offers to unmute it', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Select');
      await tapText(tester, 'Directed by');

      await tapText(tester, 'Mute');
      await flushAutosave(tester);

      final dir = app.projects.projects.values.single.blocks.firstWhere((b) => b.id == 'dir');
      expect(dir.muted, isTrue);
      expect(find.text('Unmute'), findsOneWidget);
    });

    testWidgets('Delete removes the selection, and Undo brings it back', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Select');
      await tapText(tester, 'Directed by');
      await tapText(tester, 'Music cue');

      await tapText(tester, 'Delete');
      await flushAutosave(tester);
      expect(blockIds(), ['ttl', 'cst', 'thx']);
      expect(find.text('Removed 2 blocks'), findsOneWidget);

      await tapText(tester, 'Undo');
      await flushAutosave(tester);
      expect(blockIds(), ['ttl', 'dir', 'cst', 'sng', 'thx']);
    });

    testWidgets('Restyle offers leader styles for a cast list', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Select');
      await tapText(tester, 'Cast · two column');

      await tapText(tester, 'Restyle');
      await tapText(tester, 'Rule leaders');
      await flushAutosave(tester);

      final cast = app.projects.projects.values.single.blocks.firstWhere((b) => b.id == 'cst') as PairListBlock;
      expect(cast.leader, LeaderStyle.rule);
    });
  });

  testWidgets('3.4 turning the phone opens the review monitor', (tester) async {
    await openEditor(tester);

    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();

    expect(find.text('ROTATE BACK TO EDIT'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);
    expect(find.text('5 BLOCKS'), findsNothing);

    // The chrome fades after two seconds.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    final fade = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.text('Exit'), matching: find.byType(AnimatedOpacity)).first,
    );
    expect(fade.opacity, 0);
  });

  group('3.5 swipe a block', () {
    testWidgets('Delete removes it with an undo toast naming it', (tester) async {
      await openEditor(tester);

      await tester.drag(find.text('Music cue'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Duplicate'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Removed “Music cue” · runtime'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await flushAutosave(tester);
      expect(blockIds(), ['ttl', 'dir', 'cst', 'sng', 'thx']);
    });

    testWidgets('Duplicate puts a copy right after it', (tester) async {
      await openEditor(tester);

      await tester.drag(find.text('Music cue'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await flushAutosave(tester);

      final blocks = app.projects.projects.values.single.blocks;
      expect(blocks, hasLength(6));
      expect(blocks[4], isA<SongBlock>());
      expect(blocks[4].id, isNot('sng'));
    });
  });

  group('4.1 add block', () {
    testWidgets('lists every type, and search narrows it', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Block');

      expect(find.text('Add block'), findsOneWidget);
      expect(find.text('All · 27'), findsOneWidget);
      expect(find.text('ADDS TO THE END'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'attribution');
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Add Quote'), findsOneWidget);
      expect(find.bySemanticsLabel('Add Title card'), findsNothing);
    });

    testWidgets('inserts after the focused block and opens it to fill', (tester) async {
      await openEditor(tester);

      // Tapping a row focuses it (and opens its editor).
      await tapText(tester, 'Directed by');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tapText(tester, 'Block');
      expect(find.text('INSERT AFTER · DIRECTED BY'), findsOneWidget);
      await tester.ensureVisible(find.bySemanticsLabel('Add Quote'));
      await tester.tap(find.bySemanticsLabel('Add Quote'));
      await tester.pumpAndSettle();

      expect(find.text('EDIT BLOCK · QTE'), findsOneWidget);
      await flushAutosave(tester);
      final kinds = app.projects.projects.values.single.blocks.map((b) => b.kind).toList();
      expect(kinds.indexOf(BlockKind.quote), 2);
    });
  });

  group('4.2 bulk entry', () {
    testWidgets('splits by rule, counts per rule, and fixes unparsed lines in place', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Paste');

      await tester.enterText(find.byType(TextField).first, 'Renny — Sofia Alvarez\nMarcus — Idris Oyelaran\nNkechi Obi');
      await tester.pumpAndSettle();

      expect(find.text('STRUCTURED · 2 OF 3'), findsOneWidget);
      expect(find.text('1 line couldn’t be split.'), findsOneWidget);
      expect(find.text('Add 2 rows'), findsOneWidget);
      expect(find.text('Adds to “Cast · two column”'), findsOneWidget);

      // The fix starts with the whole line as the name; nothing is guessed.
      expect(find.widgetWithText(TextField, 'Nkechi Obi'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Role'), 'Bartender');
      await tester.pumpAndSettle();
      expect(find.text('Add 3 rows'), findsOneWidget);

      await tapText(tester, 'Add 3 rows');
      await flushAutosave(tester);

      final cast = app.projects.projects.values.single.blocks.firstWhere((b) => b.id == 'cst') as PairListBlock;
      expect(cast.rows, hasLength(5));
      expect((cast.rows.last as PairCastRow).role, 'Bartender');
      expect((cast.rows.last as PairCastRow).actor, 'Nkechi Obi');
      expect(find.text('Added 3 rows'), findsOneWidget);
    });

    testWidgets('each rule chip shows how many lines it would split', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Paste');

      await tester.enterText(find.byType(TextField).first, 'Renny, Sofia\nMarcus, Idris\nVance — Helen');
      await tester.pumpAndSettle();

      expect(find.text('STRUCTURED · 2 OF 3'), findsOneWidget, reason: 'comma splits most, so it is picked');
      await tapText(tester, 'Dash —');
      expect(find.text('STRUCTURED · 1 OF 3'), findsOneWidget);
    });

    testWidgets('import from a file says it is coming', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Paste');
      await tapText(tester, 'Import file');
      expect(find.text('Import from a file is coming soon'), findsOneWidget);
    });
  });

  group('4.4 edit cast', () {
    testWidgets('fast entry hops role → name → a new row', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Cast · two column');

      expect(find.text('EDIT BLOCK · CST'), findsOneWidget);
      expect(find.text('Centre gutter'), findsOneWidget);
      expect(find.text('FAST ENTRY · NEXT HOPS ROLE → NAME → ROW'), findsOneWidget);

      final role = find.widgetWithText(TextField, 'Role').last;
      await tester.enterText(role, 'Detective');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name').last, 'Sam Whitfield');
      await tester.tap(find.text('Next'));
      await flushAutosave(tester);

      final cast = app.projects.projects.values.single.blocks.firstWhere((b) => b.id == 'cst') as PairListBlock;
      expect(cast.rows, hasLength(3));
      expect((cast.rows.last as PairCastRow).role, 'Detective');
      expect((cast.rows.last as PairCastRow).actor, 'Sam Whitfield');
    });

    testWidgets('leader style is one tap', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Cast · two column');

      await tapText(tester, 'None');
      await flushAutosave(tester);

      final cast = app.projects.projects.values.single.blocks.firstWhere((b) => b.id == 'cst') as PairListBlock;
      expect(cast.leader, LeaderStyle.clean);
    });

    testWidgets('typing a name is a single undo step', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Directed by');

      final field = find.byType(TextField).first;
      for (final s in ['D', 'Di', 'Dir']) {
        await tester.enterText(field, s);
        await tester.pump();
      }
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Undo'));
      await flushAutosave(tester);
      final dir = app.projects.projects.values.single.blocks.firstWhere((b) => b.id == 'dir') as NameListBlock;
      expect(dir.header, 'Directed by');
    });
  });

  group('sheets from the dock', () {
    testWidgets('Timing opens the timing sheet', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Timing');
      expect(find.text('Lock runtime'), findsOneWidget);
    });

    testWidgets('Export opens on the locked settings', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Export');
      expect(find.text('LOCKED FOR THIS RENDER'), findsOneWidget);
    });
  });
}
