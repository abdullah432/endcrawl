import 'package:lastreel/core/result.dart';
import 'package:lastreel/core/widgets/ec_ad_slot.dart';
import 'package:lastreel/domain/models/credit_block.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/domain/models/project.dart';
import 'package:lastreel/domain/models/project_settings.dart';
import 'package:lastreel/features/editor/screens/editor_screen.dart';
import 'package:lastreel/features/library/widgets/project_card.dart';
import 'package:lastreel/features/plan/widgets/trial_offer_card.dart';
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
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  /// [text] inside the open bottom sheet, not the library under it.
  Finder inSheet(Finder finder) => find.descendant(of: find.byType(BottomSheet), matching: finder);

  AppHarness withProjects(List<Project> projects, {Entitlement plan = const Entitlement.free()}) {
    return AppHarness(
      projects: FakeProjectRepository(seed: projects),
      plan: FakeEntitlementRepository(plan),
    );
  }

  group('1.2 empty library', () {
    testWidgets('is the template picker itself, with the reel count', (tester) async {
      await AppHarness().pump(tester);

      expect(find.text('REEL · 0 OF 2 · FREE'), findsOneWidget);
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
      await withProjects([edited, newer], plan: const Entitlement.pro(period: BillingPeriod.yearly)).pump(tester);

      final cards = tester.widgetList<ProjectCard>(find.byType(ProjectCard)).toList();
      expect(cards.map((c) => c.item.summary.title), ['Salt Flats', 'The Long Way Down']);
      expect(cards.map((c) => c.item.reel), [1, 2]);
      expect(find.text('REEL · 2 · PRO'), findsOneWidget);
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

    testWidgets('a storage failure offers a retry', (tester) async {
      final app = AppHarness();
      app.projects.failWith = const AppFailure(FailureKind.network, 'You are offline — this will sync when you reconnect.');
      await app.pump(tester);

      expect(find.text('You are offline — this will sync when you reconnect.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('+ New opens the template sheet with the reel it will take', (tester) async {
      await withProjects([_project('A', day: 1), _project('B', day: 2)],
              plan: const Entitlement.pro(period: BillingPeriod.yearly))
          .pump(tester);

      await tapText(tester, 'New');

      expect(find.text('NEW PROJECT · REEL 03'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });
  });

  group('1.6 slots full', () {
    final two = [_project('A', day: 1), _project('B', day: 2)];
    final three = [_project('A', day: 1), _project('B', day: 2), _project('C', day: 3)];

    testWidgets('the header counts both free projects', (tester) async {
      await withProjects(two).pump(tester);
      expect(find.text('REEL · 2 OF 2 · FREE'), findsOneWidget);
    });

    testWidgets('with one free project, + New still starts the second', (tester) async {
      await withProjects([_project('A', day: 1)]).pump(tester);
      expect(find.text('REEL · 1 OF 2 · FREE'), findsOneWidget);

      await tapText(tester, 'New');

      expect(find.text('NEW PROJECT · REEL 02'), findsOneWidget);
      expect(find.text('The free plan keeps'), findsNothing);
    });

    testWidgets('+ New opens the slots-full sheet, offering the trial first', (tester) async {
      await withProjects(two).pump(tester);

      await tapText(tester, 'New');

      expect(inSheet(find.text('2 OF 2 PROJECTS USED')), findsOneWidget);
      expect(inSheet(find.textContaining('two projects.', findRichText: true)), findsOneWidget);
      expect(
        find.text('Nothing was deleted and nothing expires. To start another, free up a slot or try Pro free — '
            'you won’t be charged until the trial ends.'),
        findsOneWidget,
      );
      expect(find.text('Try free'), findsOneWidget);
      expect(
        find.text(r'7 days free on monthly ($4.99), 14 days free on yearly ($29.99). Cancel before it ends and pay nothing.'),
        findsOneWidget,
      );
      expect(inSheet(find.text('Start free trial')), findsOneWidget);
      expect(find.text('Free up a slot'), findsOneWidget);
      final benefits = [
        'Unlimited projects and render history',
        'ProRes, PNG alpha and 4K exports',
        'No ads anywhere in the app',
      ].map((b) => tester.getTopLeft(find.text(b)).dy).toList();
      expect(benefits, orderedEquals([...benefits]..sort()));
    });

    testWidgets('without a trial for this account, the sheet offers the plan plainly', (tester) async {
      await AppHarness(
        projects: FakeProjectRepository(seed: two),
        plan: FakeEntitlementRepository(const Entitlement.free(lapsed: true), false),
      ).pump(tester);
      await tapText(tester, 'New');

      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.text('Start free trial'), findsNothing);
      expect(find.text('Try free'), findsNothing);
    });

    testWidgets('"Free up a slot" returns to the list with delete on each card', (tester) async {
      await withProjects(two).pump(tester);
      await tapText(tester, 'New');

      await tapText(tester, 'Free up a slot');

      expect(find.text('Delete'), findsWidgets);
      expect(find.byTooltip('Project actions'), findsNothing);
    });

    testWidgets('"Start free trial" opens the Pro sheet on the yearly trial', (tester) async {
      await withProjects(two).pump(tester);
      await tapText(tester, 'New');

      await tapText(tester, 'Start free trial');

      expect(inSheet(find.text('Start 14-day free trial')), findsOneWidget);
      // The harness clock is 23 Sep: fourteen days on is 7 Oct.
      expect(find.text(r'Free until 7 Oct, then $29.99/yr. Cancel before then and you pay nothing.'), findsOneWidget);
      expect(find.text(r'14 days free, then $2.50 a month'), findsOneWidget);
      expect(find.text(r'7 days free, then $4.99/mo'), findsOneWidget);
      expect(find.text('LASTREEL PRO'), findsOneWidget);
      expect(find.textContaining('two-project cap'), findsOneWidget);
      for (final (row, free, pro) in const [
        ('Codecs', 'H.264, HEVC', '+ ProRes, PNG'),
        ('Resolution', 'Up to 1080p', 'Up to 4K'),
        ('Pro render on Free', '1 per rewarded ad', 'Every render'),
      ]) {
        for (final cell in [row, free, pro]) {
          expect(find.text(cell), findsOneWidget);
        }
      }
      expect(inSheet(find.text('Projects')), findsOneWidget);
      expect(inSheet(find.text('2')), findsOneWidget);
      expect(inSheet(find.text('Unlimited')), findsOneWidget);
      expect(find.textContaining('Where ads show'), findsNothing);

      await tapText(tester, r'7 days free, then $4.99/mo');
      expect(inSheet(find.text('Start 7-day free trial')), findsOneWidget);
      expect(find.text(r'Free until 30 Sep, then $4.99/mo. Cancel before then and you pay nothing.'), findsOneWidget);
    });

    testWidgets('Pro has no cap', (tester) async {
      await withProjects(three, plan: const Entitlement.pro(period: BillingPeriod.monthly)).pump(tester);

      expect(find.text('REEL · 3 · PRO'), findsOneWidget);
      await tapText(tester, 'New');
      expect(find.textContaining('Pick a'), findsWidgets);
    });
  });

  group('1.1a plan card', () {
    final two = [_project('The Long Way Down', day: 1), _project('Salt Flats', day: 2)];

    testWidgets('a full free library lists both projects, then one plan card in place of the ad', (tester) async {
      final app = withProjects(two);
      await app.pump(tester);

      expect(find.text('REEL · 2 OF 2 · FREE'), findsOneWidget);
      expect(find.byType(ProjectCard), findsNWidgets(2));
      await tester.scrollUntilVisible(find.byType(TrialOfferCard), 200);
      final card = find.byType(TrialOfferCard);
      Finder inCard(Finder f) => find.descendant(of: card, matching: f);
      expect(inCard(find.text('FREE PLAN')), findsOneWidget);
      expect(inCard(find.text('2 OF 2 PROJECTS')), findsOneWidget);
      expect(inCard(find.text('Both free projects are in use')), findsOneWidget);
      expect(inCard(find.text('Try Pro free for unlimited projects, ProRes and 4K exports, and no ads.')), findsOneWidget);
      expect(inCard(find.byType(InkWell)), findsOneWidget, reason: 'one button, nothing to dismiss');
      expect(inCard(find.text('Start free trial')), findsOneWidget);
      expect(inCard(find.textContaining(r'$')), findsNothing, reason: 'no prices in the library');
      expect(inCard(find.textContaining('days free')), findsNothing);
      expect(find.byType(EcAdSlot), findsNothing);
      expect(app.analytics.names, contains('trial_card_shown'));
    });

    testWidgets('"Start free trial" opens 6.5 on the yearly trial, and starting it there is from the library',
        (tester) async {
      final app = withProjects(two);
      app.plan.purchaseGrants = Entitlement.pro(
        period: BillingPeriod.yearly,
        trialEndsAt: app.now.add(const Duration(days: 14)),
      );
      await app.pump(tester);
      await tester.scrollUntilVisible(find.byType(TrialOfferCard), 200);

      await tapText(tester, 'Start free trial');
      expect(find.text('LASTREEL PRO'), findsOneWidget);
      await tapText(tester, 'Start 14-day free trial');

      expect(app.plan.lastPurchased?.period, BillingPeriod.yearly);
      expect(app.analytics.events.last.$1, 'trial_started');
      expect(app.analytics.events.last.$2, {'plan': 'yearly', 'source': 'library'});
      expect(find.byType(TrialOfferCard), findsNothing);
      expect(find.text('REEL · PRO TRIAL · 14 DAYS LEFT'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('14d'), 200);
      expect(find.text('Trial ends 7 Oct'), findsOneWidget);
      expect(find.text('After that, two projects stay free.'), findsOneWidget);
      expect(find.byType(EcAdSlot), findsNothing);
    });

    testWidgets('one free project is not full: no card, the ad shows', (tester) async {
      await withProjects([two.first]).pump(tester);
      await tester.scrollUntilVisible(find.byType(EcAdSlot), 200);
      expect(find.byType(TrialOfferCard), findsNothing);
    });

    testWidgets('an account that has had its trial is offered the plans plainly', (tester) async {
      await AppHarness(
        projects: FakeProjectRepository(seed: two),
        plan: FakeEntitlementRepository(const Entitlement.free(lapsed: true), false),
      ).pump(tester);
      await tester.scrollUntilVisible(find.byType(TrialOfferCard), 200);

      expect(find.text('Go Pro for unlimited projects, ProRes and 4K exports, and no ads.'), findsOneWidget);
      expect(find.text('Start free trial'), findsNothing);
      await tapText(tester, 'See Pro plans');
      expect(find.text(r'Start Pro — $29.99/yr'), findsOneWidget);
    });

    testWidgets('on the trial, the countdown counts part days as days', (tester) async {
      final app = withProjects(two.take(1).toList(), plan: Entitlement.pro(trialEndsAt: DateTime.utc(2026, 9, 29, 18)));
      await app.pump(tester);
      expect(find.text('REEL · PRO TRIAL · 7 DAYS LEFT'), findsOneWidget);
      expect(find.text('Trial ends 29 Sep'), findsOneWidget);
    });
  });

  testWidgets('tapping a card again while it opens still opens one editor', (tester) async {
    final projects = FakeProjectRepository(seed: [_project('The Long Way Down', day: 1)])
      ..loadDelay = const Duration(seconds: 2);
    await AppHarness(projects: projects).pump(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('The Long Way Down'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(seconds: 2)); // the slow load finishes
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen, skipOffstage: false), findsOneWidget);

    // Once the editor has closed, the card opens again.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('The Long Way Down'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen, skipOffstage: false), findsOneWidget);
  });

  group('1.3 – 1.5, 1.7 project actions', () {
    Future<AppHarness> openActions(WidgetTester tester, {List<Project>? projects, Entitlement plan = const Entitlement.free()}) async {
      final app = withProjects(projects ?? [_project('The Long Way Down', day: 1)], plan: plan);
      await app.pump(tester);
      await tester.tap(find.byTooltip('Project actions').first);
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('the sheet names the project and what Duplicate costs', (tester) async {
      await openActions(tester);

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
      final app = await openActions(tester, plan: Entitlement.pro(trialEndsAt: DateTime.utc(2026, 9, 29)));
      await tapText(tester, 'Duplicate');

      expect(app.projects.projects, hasLength(2));
      expect(find.text('The Long Way Down (copy)'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Duplicated'), findsOneWidget);
      expect(find.text('REEL · PRO TRIAL · 2 PROJECTS'), findsOneWidget, reason: '1.7 counts projects');

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(app.projects.projects, hasLength(1));
    });

    testWidgets('duplicate is unavailable with no free slot', (tester) async {
      await openActions(tester, projects: [_project('A', day: 1), _project('B', day: 2)]);
      expect(find.text('No free slot left — Pro removes the cap'), findsOneWidget);
    });
  });

  group('7.1 settings from the library', () {
    testWidgets('the avatar opens Settings, and signing out returns to the welcome screen', (tester) async {
      await withProjects([_project('A', day: 1), _project('B', day: 2)]).pump(tester);

      await tester.tap(find.bySemanticsLabel('Account').first);
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('2 of 2 projects · ads on'), findsOneWidget);
      expect(find.text('Start free trial'), findsOneWidget);

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
      await tapText(tester, 'Start free trial');

      await tapText(tester, 'Start 14-day free trial');

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
