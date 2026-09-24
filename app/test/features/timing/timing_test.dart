import 'package:endcrawl/domain/models/project_settings.dart';
import 'package:endcrawl/features/timing/screens/background_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  late AppHarness app;

  setUp(() => app = AppHarness(projects: FakeProjectRepository(seed: [film(mode: TimingMode.duration)])));

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester) async {
    await app.pump(tester);
    await tester.tap(find.text('The Long Way Down'));
    await tester.pumpAndSettle();
  }

  Future<ProjectSettings> savedSettings(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    return app.projects.projects.values.single.settings;
  }

  group('5.1 timing', () {
    testWidgets('runtime is the input and the scroll rate is derived', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Timing');

      expect(find.text('RUNTIME · THE INPUT'), findsOneWidget);
      expect(find.textContaining('Derived scroll rate · ', findRichText: true), findsOneWidget);
      expect(find.text('Head black'), findsOneWidget);
      expect(find.text('Tail black'), findsOneWidget);

      await tester.tap(find.byTooltip('Longer by a second'));
      final settings = await savedSettings(tester);
      expect(settings.durationFrames, 24 * 60 + 24);
    });

    testWidgets('judder and dwell are reported separately', (tester) async {
      app = AppHarness(projects: FakeProjectRepository(seed: [film()]));
      await openEditor(tester);
      await tapText(tester, 'Timing');

      expect(find.text('No judder'), findsOneWidget);
      expect(find.text('Whole pixel at 1920'), findsOneWidget);
      expect(find.text('Readable'), findsOneWidget);
      expect(find.textContaining('dwell · floor 3.0s'), findsOneWidget);
    });

    testWidgets('lock speed makes the rate the input; a neighbour rate is one tap', (tester) async {
      app = AppHarness(projects: FakeProjectRepository(seed: [film()]));
      await openEditor(tester);
      await tapText(tester, 'Timing');

      expect(find.text('SPEED · THE INPUT'), findsOneWidget);
      expect(find.text('4 px/frame'), findsOneWidget);
      expect(find.textContaining('5 px/f · '), findsOneWidget);
      expect(find.textContaining('3 px/f · '), findsOneWidget);

      await tester.tap(find.textContaining('5 px/f · '));
      final settings = await savedSettings(tester);
      expect(settings.mode, TimingMode.speed);
      expect(settings.ppf, 5);
    });

    testWidgets('head black steps in half seconds, shown as seconds:frames', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Timing');
      expect(find.text('2:00'), findsOneWidget);

      await tester.tap(find.byTooltip('Increase').first);
      await tester.pumpAndSettle();

      expect(find.text('2:12'), findsOneWidget);
      expect((await savedSettings(tester)).headSeconds, 2.5);
    });
  });

  group('5.2 monitor look', () {
    testWidgets('2D is the default; tilt unlocks with 3D', (tester) async {
      await openEditor(tester);
      await tapText(tester, '2D');

      expect(find.text('DEFAULT'), findsOneWidget);
      expect(find.text('Tilt controls unlock only when 3D is selected.'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));

      await tapText(tester, '3D crawl');

      expect(find.text('22°'), findsOneWidget);
      expect((await savedSettings(tester)).look, RollLook.crawl3d);
    });

    testWidgets('leaves the monitor unscrimmed', (tester) async {
      await openEditor(tester);
      await tapText(tester, '2D');

      final barriers = tester.widgetList<ModalBarrier>(find.byType(ModalBarrier));
      expect(barriers.last.color?.a ?? 0, 0);
    });
  });

  group('5.3 background', () {
    testWidgets('every option shows a preview of the roll on it', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Black');

      final previews = find.byType(BackgroundPreview);
      expect(previews, findsNWidgets(4));
      for (final e in previews.evaluate()) {
        final size = tester.getSize(find.byWidget(e.widget));
        expect(size.width, greaterThan(100));
        expect(size.height, greaterThan(40));
      }
      expect(find.text('MAYA OKONKWO'), findsNWidgets(4));
    });

    testWidgets('Transparent is the alpha background', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Black');

      await tapText(tester, 'Transparent');
      expect((await savedSettings(tester)).background, MonitorBackground.alpha);
    });

    testWidgets('a reference clip says it is coming rather than doing nothing', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Black');

      await tapText(tester, 'Reference clip');
      expect(find.text('Reference clips are coming soon'), findsOneWidget);
      expect((await savedSettings(tester)).background, MonitorBackground.black);
    });

    testWidgets('safe-area guides switch off', (tester) async {
      await openEditor(tester);
      await tapText(tester, 'Black');

      await tapText(tester, 'Safe-area guides');
      expect((await savedSettings(tester)).safeGuides, isFalse);
    });
  });
}
