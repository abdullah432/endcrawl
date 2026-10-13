import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/config/app_links.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/desk/desk_invite.dart';
import 'package:lastreel/features/desk/desk_invite_store.dart';
import 'package:lastreel/features/library/controllers/library_controller.dart';
import 'package:lastreel/features/library/screens/library_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  final freeSheet = find.textContaining('on a big screen.', findRichText: true);
  final proSheet = find.textContaining('Try the desk.', findRichText: true);

  AppHarness harness({
    int projects = 2,
    bool isPro = false,
    InMemoryDeskInviteStore? desk,
    bool web = false,
    bool testerAllowed = false,
  }) =>
      AppHarness(
        projects: FakeProjectRepository(seed: [for (var i = 0; i < projects; i++) film()]),
        plan: isPro ? FakeEntitlementRepository(const Entitlement.pro(period: BillingPeriod.yearly)) : null,
        desk: desk ?? InMemoryDeskInviteStore(),
        web: web,
        testerAllowed: testerAllowed,
      );

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  group('1.8a free', () {
    testWidgets('a full free library sells the desk as part of Pro', (tester) async {
      final app = harness();
      await app.pump(tester);
      expect(freeSheet, findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.text('Email me the link'), findsNothing);

      await tapText(tester, 'Upgrade to Pro');
      expect(freeSheet, findsNothing);
      expect(app.analytics.names, containsAllInOrder(['desk_invite_shown', 'desk_invite_upgrade']));
    });

    testWidgets('a free library with room to spare is left alone', (tester) async {
      final app = harness(projects: 1);
      await app.pump(tester);
      expect(freeSheet, findsNothing);
    });
  });

  group('1.8b pro', () {
    testWidgets('emails the web app link from the person\'s own mail app', (tester) async {
      final app = harness(projects: 3, isPro: true);
      await app.pump(tester);
      expect(proSheet, findsOneWidget);

      await tapText(tester, 'Email me the link');
      expect(app.links.composed.single, testUser.email);
      expect(app.links.composedBodies.single, contains(AppLinks.webApp.toString()));
    });

    testWidgets('copies the link', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final app = harness(projects: 3, isPro: true);
      await app.pump(tester);
      await tester.tap(find.text('Copy link'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(copied, [AppLinks.webApp.toString()]);
      expect(find.text('Link copied. Open it on your computer.'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('two Pro projects are not enough to ask', (tester) async {
      final app = harness(projects: 2, isPro: true);
      await app.pump(tester);
      expect(proSheet, findsNothing);
    });
  });

  group('when it shows', () {
    testWidgets('Not now keeps it away for 30 days', (tester) async {
      final app = harness();
      await app.pump(tester);
      await tapText(tester, 'Not now');
      expect(freeSheet, findsNothing);
      expect(app.desk.quietUntil, app.now.add(DeskInvite.quiet));
      expect(app.desk.turnedOff, isFalse);
    });

    testWidgets('"Don\'t show this again" turns it off for good', (tester) async {
      final app = harness();
      await app.pump(tester);
      await tapText(tester, 'Don’t show this again');
      expect(app.desk.turnedOff, isTrue);
    });

    testWidgets('stays away while it is quiet', (tester) async {
      final app = harness(desk: InMemoryDeskInviteStore(quietUntil: DateTime.utc(2026, 10, 20)));
      await app.pump(tester);
      expect(freeSheet, findsNothing);
    });

    testWidgets('never on the web, which is the desk', (tester) async {
      final app = harness(projects: 3, isPro: true, web: true);
      await app.pump(tester, size: const Size(1440, 900));
      expect(proSheet, findsNothing);
    });

    test('not in a session that already asked for a rating', () {
      final view = LibraryView(
        items: [for (var i = 0; i < 2; i++) LibraryItem(film().summary, i + 1)],
        entitlement: const Entitlement.free(),
      );
      bool due({bool rated = false}) =>
          DeskInvite.due(view: view, store: InMemoryDeskInviteStore(), now: DateTime.utc(2026, 10, 13), ratedThisSession: rated, web: false);
      expect(due(), isTrue);
      expect(due(rated: true), isFalse);
    });
  });

  group('tester on iOS', () {
    final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

    Future<void> visitAnotherScreen(WidgetTester tester) async {
      final nav = Navigator.of(tester.element(find.byType(LibraryScreen)));
      nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('elsewhere'))));
      await tester.pumpAndSettle();
      nav.pop();
      await tester.pumpAndSettle();
    }

    testWidgets('shows through the quiet and the off switch, without counting', (tester) async {
      final quietUntil = DateTime.utc(2026, 11, 1);
      final app = harness(desk: InMemoryDeskInviteStore(turnedOff: true, quietUntil: quietUntil), testerAllowed: true);
      await app.pump(tester);
      expect(freeSheet, findsOneWidget);
      await tapText(tester, 'Not now');
      expect(app.desk.quietUntil, quietUntil);
    }, variant: iOS);

    testWidgets('comes back every time the library does', (tester) async {
      final app = harness(projects: 3, isPro: true, testerAllowed: true);
      await app.pump(tester);
      expect(proSheet, findsOneWidget);
      await tapText(tester, 'Not now');
      expect(proSheet, findsNothing);

      await visitAnotherScreen(tester);
      expect(proSheet, findsOneWidget);
      await tapText(tester, 'Not now');

      await visitAnotherScreen(tester);
      expect(proSheet, findsOneWidget);
    }, variant: iOS);

    testWidgets('still waits for a full library', (tester) async {
      final app = harness(projects: 1, testerAllowed: true);
      await app.pump(tester);
      expect(freeSheet, findsNothing);
    }, variant: iOS);

    testWidgets('everyone else gets it once', (tester) async {
      final app = harness(projects: 3, isPro: true);
      await app.pump(tester);
      await tapText(tester, 'Not now');
      await visitAnotherScreen(tester);
      expect(proSheet, findsNothing);
    }, variant: iOS);
  });
}
