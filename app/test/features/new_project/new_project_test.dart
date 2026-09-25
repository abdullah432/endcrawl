import 'package:endcrawl/domain/models/credit_block.dart';
import 'package:endcrawl/domain/models/project.dart';
import 'package:endcrawl/domain/models/project_settings.dart';
import 'package:endcrawl/domain/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_user_profile_repository.dart';

void main() {
  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  int continueCount(WidgetTester tester) {
    final label = tester.widget<Text>(find.textContaining('Continue with')).data!;
    return int.parse(RegExp(r'\d+').firstMatch(label)!.group(0)!);
  }

  Future<void> continueToCanvas(WidgetTester tester) async {
    final finder = find.textContaining('Continue with');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('2.2 template contents', () {
    testWidgets('a template opens its contents with every default section ticked', (tester) async {
      await AppHarness().pump(tester);
      await tapText(tester, 'Short film');

      expect(find.text('Short film template'.toUpperCase()), findsOneWidget);
      expect(find.text('7 of 7 selected'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);
    });

    testWidgets('unticking a section lowers the count and leaves it out of the project', (tester) async {
      final app = AppHarness();
      await app.pump(tester);
      await tapText(tester, 'Short film');
      final before = continueCount(tester);

      await tapText(tester, 'Directed by');

      expect(find.text('6 of 7 selected'), findsOneWidget);
      expect(continueCount(tester), before - 1);

      await continueToCanvas(tester);
      await tapText(tester, 'Open editor');

      final project = app.projects.projects.values.single;
      expect(project.blocks, hasLength(before - 1));
      expect(project.blocks.where((b) => b.kind == BlockKind.directedBy), isEmpty);
    });

    testWidgets('clearing everything disables Continue', (tester) async {
      await AppHarness().pump(tester);
      await tapText(tester, 'Short film');

      await tapText(tester, 'Clear all');

      expect(find.text('Continue with 0 blocks'), findsOneWidget);
      final button = find.ancestor(of: find.text('Continue with 0 blocks'), matching: find.byType(InkWell));
      expect(tester.widget<InkWell>(button.first).onTap, isNull);
    });
  });

  group('2.3 canvas', () {
    testWidgets('the picked canvas and frame rate go into the project', (tester) async {
      final app = AppHarness();
      await app.pump(tester);
      await tapText(tester, 'Feature film');
      await continueToCanvas(tester);

      expect(find.text('Canvas'), findsOneWidget);
      expect(find.text('Independent of how you hold the phone'), findsOneWidget);

      await tapText(tester, '9:16 vertical');
      await tapText(tester, '25');
      await tapText(tester, 'Open editor');

      final settings = app.projects.projects.values.single.settings;
      expect(settings.formatId, '9x16');
      expect(settings.fps, 25);
    });

    testWidgets('backing out before the editor saves nothing', (tester) async {
      final app = AppHarness();
      await app.pump(tester);
      await tapText(tester, 'Feature film');
      await continueToCanvas(tester);

      await tapText(tester, '1:1 square');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(app.projects.projects, isEmpty);
      expect(app.projects.saveCount, 0);
      expect(find.text('Pick a starting point.'), findsOneWidget);
    });
  });

  group('judder-free from the start', () {
    testWidgets('a template’s runtime settles on the nearest whole-pixel speed once measured', (tester) async {
      final app = AppHarness();
      await app.pump(tester);
      await tapText(tester, 'Short film');
      await continueToCanvas(tester);
      await tapText(tester, 'Open editor');
      await tester.pump(const Duration(seconds: 3)); // the autosave debounce
      await tester.pumpAndSettle();

      final settings = app.projects.projects.values.single.settings;
      expect(settings.mode, TimingMode.speed);
      expect(settings.ppf, settings.ppf.roundToDouble());
      expect(find.textContaining(' clean '), findsWidgets);
    });

    testWidgets('an empty project starts at a whole-pixel speed', (tester) async {
      final app = AppHarness();
      await app.pump(tester);
      await tapText(tester, 'Start empty');
      await tapText(tester, 'Open editor');

      final settings = app.projects.projects.values.single.settings;
      expect(settings.mode, TimingMode.speed);
      expect(settings.ppf, settings.ppf.roundToDouble());
    });
  });

  group('Start empty', () {
    testWidgets('skips the contents and uses the account defaults', (tester) async {
      final app = AppHarness(
        profile: FakeUserProfileRepository(
          const UserProfile(preferences: Preferences(defaultFps: 30, defaultFormatId: '185')),
        ),
      );
      await app.pump(tester);

      await tapText(tester, 'Start empty');

      expect(find.textContaining('Continue with'), findsNothing);
      expect(find.text('Canvas'), findsOneWidget);

      await tapText(tester, 'Open editor');

      final project = app.projects.projects.values.single;
      expect(project.blocks, isEmpty);
      expect(project.settings.fps, 30);
      expect(project.settings.formatId, '185');
      expect(find.text('No blocks yet'), findsOneWidget);
    });
  });

  testWidgets('with every slot used, the flow never starts', (tester) async {
    final app = AppHarness(
      projects: FakeProjectRepository(seed: [
        for (var i = 0; i < 3; i++) Project.create(title: 'P$i', now: DateTime.utc(2026, 9, i + 1)),
      ]),
    );
    await app.pump(tester);

    await tapText(tester, 'New');
    expect(find.text('3 OF 3 SLOTS USED'), findsOneWidget);
    expect(find.textContaining('Continue with'), findsNothing);
  });
}
