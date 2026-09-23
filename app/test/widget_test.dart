import 'package:endcrawl/core/result.dart';
import 'package:endcrawl/data/sources/session_store.dart';
import 'package:endcrawl/domain/models/credit_block.dart';
import 'package:endcrawl/domain/models/project.dart';
import 'package:endcrawl/domain/models/project_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_harness.dart';
import 'support/fake_project_repository.dart';

void main() {
  late AppHarness app;

  setUp(() => app = AppHarness());

  Future<void> pumpApp(WidgetTester tester) => app.pump(tester);

  /// Library → templates → format → editor, the full new-project path.
  Future<void> openShortFilmEditor(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Short Film'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
  }

  group('Library', () {
    testWidgets('shows an empty state when nothing is stored', (tester) async {
      await pumpApp(tester);

      expect(find.text('ENDCRAWL'), findsOneWidget);
      expect(find.text('No projects yet'), findsOneWidget);
    });

    testWidgets('lists stored projects newest first', (tester) async {
      app.projects = FakeProjectRepository(seed: [
        Project.create(title: 'OLDER').copyWith(updatedAt: DateTime.utc(2026, 1, 1)),
        Project.create(title: 'NEWER').copyWith(updatedAt: DateTime.utc(2026, 5, 1)),
      ]);
      await pumpApp(tester);

      expect(find.text('YOUR PROJECTS'), findsOneWidget);
      final titles = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      expect(titles.indexOf('NEWER') < titles.indexOf('OLDER'), isTrue);
    });

    testWidgets('offers a crash recovery for a project this device left open', (tester) async {
      final project = Project.create(title: 'THE LONG WAY DOWN');
      app.projects = FakeProjectRepository(seed: [project]);
      app.session = InMemorySessionStore(SessionState(lastOpenedProjectId: project.id, leftOpenProjectId: project.id));
      await pumpApp(tester);

      expect(find.text('RECOVERED AFTER CRASH'), findsOneWidget);
      expect(find.text('Open recovered'), findsOneWidget);
    });

    testWidgets('offers a plain resume for a project that was closed cleanly', (tester) async {
      final project = Project.create(title: 'THE LONG WAY DOWN');
      app.projects = FakeProjectRepository(seed: [project]);
      app.session = InMemorySessionStore(SessionState(lastOpenedProjectId: project.id));
      await pumpApp(tester);

      expect(find.text('CONTINUE WHERE YOU LEFT OFF'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('surfaces a storage failure with a retry', (tester) async {
      app.projects.failWith = const AppFailure(FailureKind.storage, 'Could not reach on-device storage.');
      await pumpApp(tester);

      expect(find.text('Could not reach on-device storage.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('opens a stored project into the editor', (tester) async {
      app.projects = FakeProjectRepository(seed: [
        Project.create(
          title: 'MY FILM',
          blocks: const [TitleBlock(id: 'b1', title: 'MY FILM')],
        ),
      ]);
      await pumpApp(tester);

      await tester.tap(find.text('MY FILM'));
      await tester.pumpAndSettle();

      expect(find.textContaining('blocks · drag to reorder'), findsOneWidget);
    });
  });

  group('New project flow', () {
    testWidgets('templates screen offers the starting points', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('New project'));
      await tester.pumpAndSettle();

      expect(find.text('Pick a starting point.\nChange anything later.'), findsOneWidget);
      expect(find.text('Short Film'), findsOneWidget);
    });

    testWidgets('picking a template opens the format screen', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('New project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Short Film'));
      await tester.pumpAndSettle();

      expect(find.text('Canvas format'), findsOneWidget);
    });

    testWidgets('opening the editor persists the project and renders the block list', (tester) async {
      await openShortFilmEditor(tester);

      expect(find.textContaining('blocks · drag to reorder'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);

      // Entering the editor writes the document — that is what makes it
      // appear in the library — and marks it open on this device, which is
      // what makes it recoverable.
      expect(app.projects.projects, hasLength(1));
      final stored = await app.session.read();
      expect(stored.leftOpenProjectId, app.projects.projects.keys.single);
      expect(stored.lastOpenedProjectId, app.projects.projects.keys.single);
    });

    testWidgets('leaving the editor clears the left-open mark', (tester) async {
      await openShortFilmEditor(tester);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      final stored = await app.session.read();
      expect(stored.leftOpenProjectId, isNull);
      expect(stored.lastOpenedProjectId, isNotNull);
    });

    testWidgets('an edit is autosaved without any explicit save action', (tester) async {
      await openShortFilmEditor(tester);
      final savesBeforeEdit = app.projects.saveCount;
      expect(app.projects.projects.values.single.settings.look, RollLook.flat2d);

      await tester.tap(find.text('2D'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3D perspective crawl'));
      await tester.pumpAndSettle();

      // Nothing is written yet — the autosave is debounced so a burst of
      // edits coalesces into one write.
      expect(app.projects.saveCount, savesBeforeEdit);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(app.projects.saveCount, greaterThan(savesBeforeEdit));
      expect(app.projects.projects.values.single.settings.look, RollLook.crawl3d);
    });

    testWidgets('start empty reaches an editor with no blocks', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('New project'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Start empty'), 300);
      await tester.tap(find.text('Start empty'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      expect(find.text('No blocks yet'), findsOneWidget);
    });
  });

  group('Editor', () {
    testWidgets('timing sheet opens and shows the judder/readability cards', (tester) async {
      await openShortFilmEditor(tester);

      await tester.tap(find.text('Timing'));
      await tester.pumpAndSettle();

      expect(find.text('Lock runtime'), findsOneWidget);
      expect(find.text('Head black'), findsOneWidget);
    });

    testWidgets('paste & split sheet parses the seed cast list', (tester) async {
      await openShortFilmEditor(tester);

      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();

      expect(find.text('Paste & split'), findsOneWidget);
      expect(find.textContaining('Add '), findsWidgets);
    });

    testWidgets('export sheet opens on the idle/locked-settings state', (tester) async {
      await openShortFilmEditor(tester);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(find.text('LOCKED FOR THIS RENDER'), findsOneWidget);
      expect(find.text('ProRes 4444'), findsWidgets);
    });

    testWidgets('tapping the cast block card opens the cast editor', (tester) async {
      await openShortFilmEditor(tester);

      await tester.scrollUntilVisible(find.text('Cast'), 300);
      await tester.tap(find.text('Cast'));
      await tester.pumpAndSettle();

      expect(find.text('Centre gutter'), findsOneWidget);
      expect(find.text('FAST ENTRY — NEXT HOPS ROLE → NAME → NEW ROW'), findsOneWidget);
    });

    testWidgets('select mode shows the bulk action bar', (tester) async {
      await openShortFilmEditor(tester);

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('0 selected'), findsOneWidget);
      expect(find.text('Restyle'), findsOneWidget);
    });

    testWidgets('rotating to landscape shows the full-bleed monitor', (tester) async {
      await openShortFilmEditor(tester);

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();

      expect(find.textContaining('FULL-BLEED MONITOR'), findsOneWidget);
    });
  });
}
