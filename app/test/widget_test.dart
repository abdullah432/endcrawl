import 'package:endcrawl/domain/models/project_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/app_harness.dart';

void main() {
  late AppHarness app;

  setUp(() => app = AppHarness());

  Future<void> pumpApp(WidgetTester tester) => app.pump(tester);

  /// Empty library → template → format → editor, the new-project path.
  Future<void> openShortFilmEditor(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Feature film'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
  }

  group('New project flow', () {
    testWidgets('picking a template opens the format screen', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Short film'));
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
      await tester.ensureVisible(find.text('Start empty'));
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

      // Scroll past it a little: the floating action bar covers the last
      // row of the viewport.
      await tester.scrollUntilVisible(find.text('Cast · two column'), 300);
      await tester.drag(find.text('Cast · two column'), const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cast · two column'));
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
