import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/desk/desk_invite_store.dart';
import 'package:lastreel/features/tracking/tracking_authorization.dart';
import 'package:lastreel/features/tracking/tracking_prompt.dart';
import 'package:lastreel/features/tracking/tracking_store.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 9, 23, 12);
  final prePrompt = find.textContaining('Keep LastReel free,', findRichText: true);
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  AppHarness harness({Duration installedFor = const Duration(days: 3), bool isPro = false, bool done = false}) =>
      AppHarness(
        projects: FakeProjectRepository(seed: [film()]),
        plan: isPro ? FakeEntitlementRepository(const Entitlement.pro(period: BillingPeriod.yearly)) : null,
        tracking: InMemoryTrackingStore(firstSeen: now.subtract(installedFor), prePromptDone: done),
        now: now,
      );

  group('when it is due', () {
    bool due({
      Duration installedFor = const Duration(days: 3),
      bool ios = true,
      bool free = true,
      bool web = false,
      bool done = false,
      bool recorded = true,
    }) => TrackingPrompt.due(
      store: InMemoryTrackingStore(firstSeen: recorded ? now.subtract(installedFor) : null, prePromptDone: done),
      now: now,
      ios: ios,
      free: free,
      web: web,
    );

    test('three days after the first launch, not before', () {
      expect(due(installedFor: const Duration(days: 2, hours: 23)), isFalse);
      expect(due(installedFor: const Duration(days: 3)), isTrue);
      expect(due(installedFor: const Duration(days: 40)), isTrue);
    });

    test('only on iOS, on Free, outside the web, and once', () {
      expect(due(ios: false), isFalse);
      expect(due(free: false), isFalse);
      expect(due(web: true), isFalse);
      expect(due(done: true), isFalse);
      expect(due(recorded: false), isFalse);
    });

    test('the first launch is recorded once and kept', () async {
      final store = InMemoryTrackingStore();
      await store.recordFirstSeen(now);
      await store.recordFirstSeen(now.add(const Duration(days: 5)));
      expect(store.firstSeen, now);
    });
  });

  testWidgets('day 3 on Free: the pre-prompt, then iOS asks, and never again', (tester) async {
    final app = harness();
    await app.pump(tester);
    expect(prePrompt, findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    // One action only: no close and no "Not now".
    expect(find.byTooltip('Close'), findsNothing);
    expect(find.text('Not now'), findsNothing);
    expect(app.tracking.prePromptDone, isTrue);
    expect(app.analytics.names, contains('att_preprompt_shown'));
    expect(app.trackingAuthorization.requests, 0);

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(prePrompt, findsNothing);
    expect(app.trackingAuthorization.requests, 1);
    expect(app.analytics.names, containsAllInOrder(['att_preprompt_continue', 'att_result']));
    expect(app.analytics.events.last.$2, {'status': 'authorized'});
  }, variant: ios);

  testWidgets('not in the first three days', (tester) async {
    final app = harness(installedFor: const Duration(days: 2));
    await app.pump(tester);
    expect(prePrompt, findsNothing);
    expect(app.tracking.prePromptDone, isFalse);
  }, variant: ios);

  testWidgets('never once shown', (tester) async {
    final app = harness(done: true);
    await app.pump(tester);
    expect(prePrompt, findsNothing);
  }, variant: ios);

  testWidgets('Pro is never asked', (tester) async {
    final app = harness(isPro: true);
    await app.pump(tester);
    expect(prePrompt, findsNothing);
    expect(app.tracking.prePromptDone, isFalse);
  }, variant: ios);

  testWidgets('never on Android', (tester) async {
    final app = harness();
    await app.pump(tester);
    expect(prePrompt, findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('already decided in iOS: skipped for good', (tester) async {
    final app = harness()..trackingAuthorization.current = TrackingAuthorizationStatus.denied;
    await app.pump(tester);
    expect(prePrompt, findsNothing);
    expect(app.tracking.prePromptDone, isTrue);
    expect(app.trackingAuthorization.requests, 0);
  }, variant: ios);

  testWidgets('keeps the desk invite out of its session', (tester) async {
    final app = harness()..desk = InMemoryDeskInviteStore();
    await app.pump(tester);
    expect(prePrompt, findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(app.analytics.names, isNot(contains('desk_invite_shown')));
  }, variant: ios);

  for (final (size, art) in [(const Size(1194, 834), false), (const Size(834, 1194), true)]) {
    testWidgets('a centred card on a tablet at $size', (tester) async {
      final app = harness();
      await app.pump(tester, size: size);
      expect(prePrompt, findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      final card = find.ancestor(of: prePrompt, matching: find.byType(SingleChildScrollView)).first;
      expect(tester.getSize(card).width, lessThanOrEqualTo(560));
      // A5: portrait has the height for the art.
      expect(find.text('A FEW QUIET ADS'), art ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    }, variant: ios);
  }
}
