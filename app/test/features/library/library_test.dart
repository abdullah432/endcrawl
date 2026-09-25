import 'package:lastreel/core/result.dart';
import 'package:lastreel/core/widgets/ec_ad_slot.dart';
import 'package:lastreel/domain/models/credit_block.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/domain/models/project.dart';
import 'package:lastreel/domain/models/project_settings.dart';
import 'package:lastreel/features/library/widgets/project_card.dart';
import 'package:lastreel/features/library/widgets/slot_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';

Project _project(String title, {required int day, List<CreditBlock> blocks = const []}) {
  final created = DateTime.utc(2026, 9, day);
  return Project.create(
    title: title,
    blocks: blocks,
    now: created,
    settings: const ProjectSettings(formatId: '239', fps: 24, durationFrames: 24 * 102),
  );
}

void main() {
  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  AppHarness withProjects(List<Project> projects, {Entitlement plan = const Entitlement.free()}) {
    return AppHarness(
      projects: FakeProjectRepository(seed: projects),
      plan: FakeEntitlementRepository(plan),
    );
  }

  group('1.2 empty library', () {
    testWidgets('is the template picker itself, with the reel count', (tester) async {
      await AppHarness().pump(tester);

      expect(find.text('REEL · 0 OF 3 · FREE'), findsOneWidget);
      expect(find.text('Pick a starting point.'), findsOneWidget);
      expect(find.text('Feature film'), findsOneWidget);
      expect(find.text('Vertical social cut'), findsOneWidget);
      expect(find.text('Start empty'), findsOneWidget);
      expect(find.text('New'), findsNothing, reason: 'the template list is the way in');
    });

    testWidgets('template meta is derived from what the template creates', (tester) async {
      await AppHarness().pump(tester);
      expect(find.textContaining('24 fps · 2.39:1 · 27 blocks'), findsOneWidget);
      expect(find.textContaining('30 fps · 9:16 · 6 blocks'), findsOneWidget);
    });

    testWidgets('shows an ad on the free plan, and none on Pro', (tester) async {
      await AppHarness().pump(tester);
      await tester.scrollUntilVisible(find.byType(EcAdSlot), 200);
      expect(find.byType(EcAdSlot), findsOneWidget);
    });

    testWidgets('Pro sees no ad', (tester) async {
      await AppHarness(plan: FakeEntitlementRepository(const Entitlement.pro(period: BillingPeriod.yearly))).pump(tester);
      expect(find.byType(EcAdSlot), findsNothing);
    });
  });

  group('1.1 library home', () {
    testWidgets('lists projects newest first, numbered by creation like reels', (tester) async {
      final older = _project('Salt Flats', day: 1);
      final newer = _project('The Long Way Down', day: 2);
      // Salt Flats was created first but edited last.
      final edited = older.copyWith(updatedAt: DateTime.utc(2026, 9, 20));
      await withProjects([edited, newer]).pump(tester);

      final cards = tester.widgetList<ProjectCard>(find.byType(ProjectCard)).toList();
      expect(cards.map((c) => c.item.summary.title), ['Salt Flats', 'The Long Way Down']);
      expect(cards.map((c) => c.item.reel), [1, 2]);
      expect(find.text('REEL · 2 OF 3 · FREE'), findsOneWidget);
    });

    testWidgets('each card shows the first credit and the runtime', (tester) async {
      await withProjects([
        _project('The Long Way Down', day: 1, blocks: const [
          NameListBlock(id: 'd', header: 'Directed by', names: ['Maya Okonkwo']),
        ]),
      ]).pump(tester);

      expect(find.text('DIRECTED BY'), findsOneWidget);
      expect(find.text('MAYA OKONKWO'), findsOneWidget);
      expect(find.textContaining('01:42 · 24 fps'), findsOneWidget);
      expect(find.text('2.39:1'), findsOneWidget);
    });

    testWidgets('shows the next empty reel as a slot', (tester) async {
      await withProjects([_project('A', day: 1), _project('B', day: 2)]).pump(tester);

      final slot = tester.widget<SlotCard>(find.byType(SlotCard));
      expect(slot.reel, 3);
      expect(find.text('One slot left'), findsOneWidget);
    });

    testWidgets('a storage failure offers a retry', (tester) async {
      final app = AppHarness();
      app.projects.failWith = const AppFailure(FailureKind.network, 'You are offline — this will sync when you reconnect.');
      await app.pump(tester);

      expect(find.text('You are offline — this will sync when you reconnect.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('+ New opens the template sheet with the slot it will take', (tester) async {
      await withProjects([_project('A', day: 1)]).pump(tester);

      await tapText(tester, 'New');

      expect(find.text('NEW PROJECT · SLOT 2 OF 3'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });
  });

  group('1.6 slots full', () {
    final three = [_project('A', day: 1), _project('B', day: 2), _project('C', day: 3)];

    testWidgets('the header says the reel is full', (tester) async {
      await withProjects(three).pump(tester);
      expect(find.text('REEL · 3 OF 3 · FULL'), findsOneWidget);
      expect(find.byType(SlotCard), findsNothing);
    });

    testWidgets('+ New opens the slots-full sheet instead of the templates', (tester) async {
      await withProjects(three).pump(tester);

      await tapText(tester, 'New');

      expect(find.text('3 OF 3 SLOTS USED'), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.text('Free up a slot'), findsOneWidget);
      final benefits = [
        'Unlimited projects and render history',
        'ProRes, PNG alpha and 4K exports',
        'No ads anywhere in the app',
      ].map((b) => tester.getTopLeft(find.text(b)).dy).toList();
      expect(benefits, orderedEquals([...benefits]..sort()));
    });

    testWidgets('"Free up a slot" returns to the list with delete on each card', (tester) async {
      await withProjects(three).pump(tester);
      await tapText(tester, 'New');

      await tapText(tester, 'Free up a slot');

      expect(find.text('Delete'), findsWidgets);
      expect(find.byTooltip('Project actions'), findsNothing);
    });

    testWidgets('"Upgrade to Pro" opens the Pro sheet', (tester) async {
      await withProjects(three).pump(tester);
      await tapText(tester, 'New');

      await tapText(tester, 'Upgrade to Pro');

      expect(find.textContaining('Start Pro — \$29.99/yr'), findsOneWidget);
      expect(find.text('LASTREEL PRO'), findsOneWidget);
      for (final (row, free, pro) in const [
        ('Codecs', 'H.264, HEVC', '+ ProRes, PNG'),
        ('Resolution', 'Up to 1080p', 'Up to 4K'),
        ('Pro render on Free', '1 per rewarded ad', 'Every render'),
      ]) {
        for (final cell in [row, free, pro]) {
          expect(find.text(cell), findsOneWidget);
        }
      }
      expect(find.textContaining('Where ads show'), findsNothing);
    });

    testWidgets('Pro has no cap', (tester) async {
      await withProjects(three, plan: const Entitlement.pro(period: BillingPeriod.monthly)).pump(tester);

      expect(find.text('REEL · 3 · PRO'), findsOneWidget);
      await tapText(tester, 'New');
      expect(find.textContaining('Pick a'), findsWidgets);
    });
  });

  group('1.3 – 1.5, 1.7 project actions', () {
    Future<AppHarness> openActions(WidgetTester tester, {List<Project>? projects}) async {
      final app = withProjects(projects ?? [_project('The Long Way Down', day: 1)]);
      await app.pump(tester);
      await tester.tap(find.byTooltip('Project actions').first);
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('the sheet names the project and what Duplicate costs', (tester) async {
      await openActions(tester, projects: [_project('A', day: 1), _project('The Long Way Down', day: 2)]);

      expect(find.text('The Long Way Down'), findsWidgets);
      expect(find.text('Uses your last free slot'), findsOneWidget);
      expect(find.text('Delete project'), findsOneWidget);
    });

    testWidgets('rename saves the new name', (tester) async {
      final app = await openActions(tester);
      await tapText(tester, 'Rename');

      await tester.enterText(find.byType(TextField), 'Salt Flats');
      await tester.pump();
      await tapText(tester, 'Save');

      expect(app.projects.projects.values.single.title, 'Salt Flats');
    });

    testWidgets('delete asks first, then undo puts the project back', (tester) async {
      final app = await openActions(tester);
      final original = app.projects.projects.values.single;
      await tapText(tester, 'Delete project');

      expect(find.text('Keep it'), findsOneWidget);
      await tester.tap(find.widgetWithText(InkWell, 'Delete project').last);
      await tester.pumpAndSettle();

      expect(app.projects.projects, isEmpty);
      expect(find.text('Deleted “The Long Way Down”'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(app.projects.projects.values.single.id, original.id);
    });

    testWidgets('a project that can’t be read still deletes, just without undo', (tester) async {
      final app = await openActions(tester);
      final original = app.projects.projects.values.single;
      app.projects.unreadable.add(original.id);
      await tapText(tester, 'Delete project');
      await tester.tap(find.widgetWithText(InkWell, 'Delete project').last);
      await tester.pumpAndSettle();

      expect(app.projects.projects, isEmpty);
      expect(find.text('Deleted “The Long Way Down”'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('duplicate highlights the copy with Open and Rename, and can be undone', (tester) async {
      final app = await openActions(tester);
      await tapText(tester, 'Duplicate');

      expect(app.projects.projects, hasLength(2));
      expect(find.text('The Long Way Down (copy)'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Duplicated'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(app.projects.projects, hasLength(1));
    });

    testWidgets('duplicate is unavailable with no free slot', (tester) async {
      await openActions(tester, projects: [_project('A', day: 1), _project('B', day: 2), _project('C', day: 3)]);
      expect(find.text('No free slots — Pro removes the cap'), findsOneWidget);
    });
  });

  group('7.1 settings from the library', () {
    testWidgets('the avatar opens Settings, and signing out returns to the welcome screen', (tester) async {
      await withProjects([_project('A', day: 1)]).pump(tester);

      await tester.tap(find.bySemanticsLabel('Account').first);
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('1 of 3 projects · ads on'), findsOneWidget);

      await tapText(tester, 'Sign out');

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('a preference switch is saved to the account', (tester) async {
      final app = withProjects([_project('A', day: 1)]);
      await app.pump(tester);
      await tester.tap(find.bySemanticsLabel('Account').first);
      await tester.pumpAndSettle();

      await tapText(tester, 'Haptics');

      expect(app.profile.profile.preferences.haptics, isFalse);
    });

    testWidgets('purchases say plainly that they are not available yet', (tester) async {
      final app = withProjects([_project('A', day: 1)]);
      await app.pump(tester);
      await tester.tap(find.bySemanticsLabel('Account').first);
      await tester.pumpAndSettle();
      await tapText(tester, 'Upgrade to Pro');

      await tapText(tester, 'Start Pro — \$29.99/yr');

      expect(app.plan.purchases, 1);
      expect(find.textContaining('Purchases aren’t available in this build yet'), findsOneWidget);
    });
  });

  testWidgets('the list follows the store live — no refresh needed', (tester) async {
    final a = _project('Kept', day: 1);
    final b = _project('Gone elsewhere', day: 2);
    final app = withProjects([a, b]);
    await app.pump(tester);
    expect(find.text('Gone elsewhere'), findsOneWidget);

    // Deleted outside the library — another device, or account deletion.
    await app.projects.delete(b.id);
    await tester.pumpAndSettle();

    expect(find.text('Gone elsewhere'), findsNothing);
    expect(find.text('Kept'), findsOneWidget);
  });
}
