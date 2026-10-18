import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/bootstrap.dart';
import 'package:lastreel/core/widgets/ec_ad_slot.dart';
import 'package:lastreel/domain/models/credit_block.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/domain/models/project.dart';
import 'package:lastreel/features/desk/desk_invite.dart';
import 'package:lastreel/features/desk/desk_invite_store.dart';
import 'package:lastreel/features/editor/screens/editor_screen.dart';
import 'package:lastreel/features/library/controllers/library_controller.dart';
import 'package:lastreel/features/plan/controllers/editable_projects.dart';
import 'package:lastreel/features/plan/controllers/plan_controller.dart';
import 'package:lastreel/features/plan/controllers/release_policy.dart';
import 'package:lastreel/features/plan/screens/pro_sheet.dart';
import 'package:lastreel/features/plan/widgets/slots_full_sheet.dart';
import 'package:lastreel/features/plan/widgets/trial_offer_card.dart';
import 'package:lastreel/features/project/controllers/project_controller.dart';
import 'package:lastreel/features/settings/screens/settings_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';

void main() {
  final sizes = [
    AppHarness.phone,
    const Size(1194, 834),
    const Size(1440, 1024),
  ];
  final seed = [
    for (var day = 1; day <= 3; day++)
      Project.create(
        title: 'Film $day',
        now: DateTime.utc(2026, 9, day),
        blocks: [
          NameListBlock(
            id: 'names-$day',
            header: 'Cast',
            names: const ['Maya'],
          ),
        ],
      ),
  ];

  AppHarness launch({
    bool enabled = true,
    Entitlement plan = const Entitlement.free(lapsed: true),
  }) => AppHarness(
    iosFreeLaunch: enabled,
    projects: FakeProjectRepository(seed: seed),
    plan: FakeEntitlementRepository(plan),
    desk: InMemoryDeskInviteStore(),
  );

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> text(WidgetTester tester, String value) =>
      tap(tester, find.text(value).last);

  void iosTest(String name, WidgetTesterCallback body) => testWidgets(
    name,
    body,
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final size in sizes) {
    iosTest('creates and duplicates beyond two projects, with undo, at $size', (
      tester,
    ) async {
      final app = launch();
      await app.pump(tester, size: size);
      final c = container(tester);
      expect(c.read(projectLimitProvider), isNull);
      expect(c.read(readOnlyProjectIdsProvider), isEmpty);
      expect(
        c.read(libraryViewProvider).requireValue.reelLabel(),
        'Reel · 3 · Free',
      );
      expect(find.byType(TrialOfferCard), findsNothing);
      expect(find.byType(TrialReminderRow), findsNothing);
      if (size.width == 1194) {
        expect(find.text('REEL · 3 PROJECTS · FREE'), findsOneWidget);
        expect(find.text('3 projects · ads on'), findsOneWidget);
      }

      // Exercise the real phone sheet and tablet/expanded dialog paths.
      await text(tester, size == AppHarness.phone ? 'New' : 'New project');
      expect(find.byType(SlotsFullSheet), findsNothing);
      await text(tester, 'Start empty');
      if (size == AppHarness.phone) {
        await text(tester, 'Continue');
        await text(tester, 'Open editor');
      } else {
        await text(tester, 'Create project');
      }
      expect(find.byType(EditorScreen), findsOneWidget);
      expect(app.projects.projects, hasLength(4));
      Navigator.of(tester.element(find.byType(EditorScreen))).pop();
      await tester.pumpAndSettle();

      await tap(tester, find.byTooltip('Project actions').first);
      await text(tester, 'Duplicate');
      expect(app.projects.projects, hasLength(5));
      expect(find.text('Duplicated'), findsOneWidget);
      expect(find.text('Duplicated · slots now full'), findsNothing);
      await text(tester, 'Undo');
      expect(app.projects.projects, hasLength(4));
      for (final project in seed) {
        expect(app.projects.projects[project.id]!.toJson(), project.toJson());
      }
      expect(app.plan.purchases, 0);
      expect(app.plan.offerRequests, 0);
      expect(tester.takeException(), isNull);
    });

    iosTest(
      'hides subscription and Desktop prompts without consuming invite state at $size',
      (tester) async {
        final app = launch()..testerAllowed = true;
        await app.pump(tester, size: size);
        final c = container(tester);
        final context = tester.element(find.byType(Scaffold).first);
        await DeskInvite.maybeShow(context);
        await DeskInvite.showNow(context);
        await ProSheet.show(context);
        await tester.pumpAndSettle();
        expect(c.read(deskInviteShownThisSessionProvider), isFalse);
        expect(c.read(deskInviteOpenProvider), isFalse);
        expect(app.desk.quietUntil, isNull);
        expect(app.desk.turnedOff, isFalse);
        expect(app.desk.sessions, 10);
        expect(
          app.analytics.names.where((name) => name.startsWith('desk_invite')),
          isEmpty,
        );
        expect(find.byType(ProSheet), findsNothing);

        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Desktop & web'), findsNothing);
        expect(find.text('Show desk invite now'), findsNothing);
        expect(find.text('Free plan'), findsNothing);
        expect(find.text('Upgrade to Pro'), findsNothing);
        expect(find.text('Start free trial'), findsNothing);
        expect(find.text('Restore'), findsNothing);
        expect(find.text('Plan'), findsNothing);
        expect(find.text('LastReel Pro (tester)'), findsOneWidget);
        expect(find.text('Frame rate'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  iosTest(
    'all existing projects open unchanged, then accept and persist edits and renames',
    (tester) async {
      final app = launch();
      await app.pump(tester);
      final c = container(tester);
      final controller = c.read(projectControllerProvider.notifier);
      for (final project in seed) {
        await controller.openProject(project.id);
        await controller.markOpened();
        expect(app.projects.projects[project.id]!.toJson(), project.toJson());
        expect(controller.readOnly, isFalse);
        controller.addBlock(SpacerBlock(id: 'extra-${project.id}'));
        await controller.flushPendingSave();
        final renamed = await c
            .read(libraryControllerProvider)
            .rename(project.id, '${project.title} renamed');
        expect(renamed.isOk, isTrue);
        final stored = app.projects.projects[project.id]!;
        expect(stored.blocks, hasLength(2));
        expect(stored.title, '${project.title} renamed');
        expect(stored.createdAt, project.createdAt);
      }
      expect(app.projects.projects, hasLength(3));
      expect(c.read(readOnlyProjectIdsProvider), isEmpty);
    },
  );

  iosTest(
    'defensive plan actions cannot load offers or purchase during free launch',
    (tester) async {
      final app = launch();
      await app.pump(tester);
      final c = container(tester);
      final subscription = c.listen(planControllerProvider, (_, _) {});
      addTearDown(subscription.close);
      final plan = c.read(planControllerProvider.notifier);
      await plan.loadOffers();
      plan.select(
        const PlanOffer(
          period: BillingPeriod.yearly,
          price: r'$29.99',
          detail: '',
          packageId: 'yearly',
        ),
      );
      expect(await plan.purchase(), isFalse);
      expect(app.plan.offerRequests, 0);
      expect(app.plan.purchases, 0);
      expect(c.read(entitlementProvider).requireValue.isPro, isFalse);
    },
  );

  iosTest(
    'native and resume ads remain enabled without their subscription link',
    (tester) async {
      final app = launch();
      await app.pump(tester);
      await tester.scrollUntilVisible(find.byType(EcAdSlot), 200);
      expect(find.text('SPONSORED'), findsOneWidget);
      expect(find.text('HIDE ADS'), findsNothing);
      expect(tester.widget<EcAdSlot>(find.byType(EcAdSlot)).onHideAds, isNull);
      expect(app.ads.appOpenShown, 0);
      expect(app.ads.appOpenPreloaded, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      app.now = app.now.add(const Duration(seconds: 15));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(app.ads.appOpenShown, 1);
    },
  );

  iosTest('trial reminders stay hidden without changing real Pro benefits', (
    tester,
  ) async {
    final app = launch(
      plan: Entitlement.pro(trialEndsAt: DateTime.utc(2026, 10, 7)),
    );
    await app.pump(tester);
    expect(find.byType(TrialReminderRow), findsNothing);
    expect(find.byType(EcAdSlot), findsNothing);
    expect(
      container(tester).read(entitlementProvider).requireValue.isPro,
      isTrue,
    );
    expect(app.ads.appOpenPreloaded, 0);
  });

  iosTest(
    'disabling the flag restores limits and subscription UI without deleting projects',
    (tester) async {
      final app = launch(enabled: false)..desk.turnedOff = true;
      await app.pump(tester);
      final c = container(tester);
      expect(c.read(projectLimitProvider), 2);
      expect(c.read(readOnlyProjectIdsProvider), {seed.first.id});
      expect(await c.read(libraryControllerProvider).canAddProject(), isFalse);
      final duplicate = await c
          .read(libraryControllerProvider)
          .duplicate(seed.first.id);
      expect(duplicate.isOk, isFalse);
      expect(app.projects.projects, hasLength(3));
      await text(tester, 'New');
      expect(find.byType(SlotsFullSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(SlotsFullSheet))).pop();
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Free plan'), findsOneWidget);
      expect(find.text('Desktop & web'), findsOneWidget);
      expect(find.text('Start free trial'), findsOneWidget);
      expect(app.plan.offerRequests, greaterThan(0));
      for (final project in seed) {
        expect(app.projects.projects[project.id]!.toJson(), project.toJson());
      }
    },
  );
}
