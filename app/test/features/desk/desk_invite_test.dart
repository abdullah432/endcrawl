import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/config/app_links.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/desk/desk_invite.dart';
import 'package:lastreel/features/desk/desk_invite_store.dart';
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
    testWidgets('sells the desk as part of Pro', (tester) async {
      final app = harness();
      await app.pump(tester);
      expect(freeSheet, findsOneWidget);
      expect(find.text('LASTREEL PRO · DESKTOP & WEB'), findsOneWidget);
      expect(find.text('Upgrade to Pro'), findsOneWidget);
      expect(find.text('Preview on the web'), findsOneWidget);
      expect(find.text('Email me the link'), findsNothing);
      expect(find.text('We’ll send the link to'), findsNothing);

      await tapText(tester, 'Upgrade to Pro');
      expect(freeSheet, findsNothing);
      expect(app.analytics.names, containsAllInOrder(['desk_invite_shown', 'desk_invite_upgrade']));
    });

    testWidgets('Preview on the web opens the web app', (tester) async {
      final app = harness();
      await app.pump(tester);
      await tapText(tester, 'Preview on the web');
      expect(freeSheet, findsNothing);
      expect(app.links.opened, [AppLinks.webApp]);
      expect(app.analytics.names, contains('desk_invite_preview'));
    });

    testWidgets('shows whatever the library holds — one project or many', (tester) async {
      final app = harness(projects: 1);
      await app.pump(tester);
      expect(freeSheet, findsOneWidget);
    });

    testWidgets('the ✕ closes it like Not now', (tester) async {
      final app = harness();
      await app.pump(tester);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(freeSheet, findsNothing);
      expect(app.desk.turnedOff, isFalse);
      expect(app.analytics.names, contains('desk_invite_later'));
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

    testWidgets('names the signed-in address, and Change sends it elsewhere', (tester) async {
      final app = harness(projects: 3, isPro: true);
      await app.pump(tester);
      expect(find.text('INCLUDED WITH YOUR PRO PLAN'), findsOneWidget);
      expect(find.text(testUser.email!), findsOneWidget);

      await tapText(tester, 'Change');
      await tester.enterText(find.byType(EditableText), 'desk@studio.test');
      await tester.pump();
      await tapText(tester, 'Done');
      expect(find.text('desk@studio.test'), findsOneWidget);

      await tapText(tester, 'Email me the link');
      expect(app.links.composed.single, 'desk@studio.test');
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

    testWidgets('"Don\'t show this again" is a checkbox that counts however it closes', (tester) async {
      final app = harness();
      await app.pump(tester);
      await tapText(tester, 'Don’t show this again');
      expect(freeSheet, findsOneWidget, reason: 'ticking it does not close the sheet');
      expect(app.desk.turnedOff, isFalse);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(app.desk.turnedOff, isTrue);
      expect(app.analytics.names, contains('desk_invite_never'));
    });

    testWidgets('unticked again, it stays on', (tester) async {
      final app = harness();
      await app.pump(tester);
      await tapText(tester, 'Don’t show this again');
      await tapText(tester, 'Don’t show this again');
      await tapText(tester, 'Not now');
      expect(app.desk.turnedOff, isFalse);
    });

    testWidgets('stays away while it is quiet', (tester) async {
      final app = harness(desk: InMemoryDeskInviteStore(quietUntil: DateTime.utc(2026, 10, 20)));
      await app.pump(tester);
      expect(freeSheet, findsNothing);
    });

    testWidgets('not in the first three sessions', (tester) async {
      final app = harness(desk: InMemoryDeskInviteStore(sessions: DeskInvite.firstSessions));
      await app.pump(tester);
      expect(freeSheet, findsNothing);
      expect(app.desk.quietUntil, isNull);
    });

    testWidgets('by chance: a session that loses the roll waits for another', (tester) async {
      final app = harness()..deskChance = false;
      await app.pump(tester);
      expect(freeSheet, findsNothing);
      expect(app.desk.quietUntil, isNull, reason: 'not counted as shown');
    });

    testWidgets('never on the web, which is the desk', (tester) async {
      final app = harness(projects: 3, isPro: true, web: true);
      await app.pump(tester, size: const Size(1440, 900));
      expect(proSheet, findsNothing);
    });

    test('the rules, one by one', () {
      final now = DateTime.utc(2026, 10, 13);
      bool due({bool rated = false, bool web = false, int sessions = 10, DateTime? quietUntil, bool off = false}) =>
          DeskInvite.due(
            store: InMemoryDeskInviteStore(sessions: sessions, quietUntil: quietUntil, turnedOff: off),
            now: now,
            ratedThisSession: rated,
            web: web,
          );
      expect(due(), isTrue);
      expect(due(rated: true), isFalse, reason: 'not in a session that already asked for a rating');
      expect(due(web: true), isFalse);
      expect(due(off: true), isFalse);
      expect(due(sessions: 3), isFalse);
      expect(due(sessions: 4), isTrue);
      expect(due(quietUntil: now.add(const Duration(days: 1))), isFalse);
      expect(due(quietUntil: now), isTrue, reason: '30 days on, it may show again');
    });

    test('counts each start of the app', () async {
      final store = InMemoryDeskInviteStore(sessions: 0);
      await store.countSession();
      await store.countSession();
      expect(store.sessions, 2);
    });
  });

  group('1.8c the web at phone width', () {
    testWidgets('a phone-width browser gets "made for bigger screens"', (tester) async {
      final app = harness(projects: 3, isPro: true, web: true);
      await app.pump(tester);
      expect(find.textContaining('bigger screens.', findRichText: true), findsOneWidget);
      expect(find.text('Sends to ${testUser.email}'), findsOneWidget);

      await tapText(tester, 'Email me this link');
      expect(app.links.composed.single, testUser.email);
      expect(app.links.composedBodies.single, contains(AppLinks.webApp.toString()));
    });

    testWidgets('free accounts too, from Preview on the web', (tester) async {
      final app = harness(web: true);
      await app.pump(tester);
      expect(find.textContaining('bigger screens.', findRichText: true), findsOneWidget);
    });

    testWidgets('widening the window loads the app, no reload', (tester) async {
      final app = harness(projects: 3, isPro: true, web: true);
      await app.pump(tester);
      expect(find.textContaining('bigger screens.', findRichText: true), findsOneWidget);
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      expect(find.textContaining('bigger screens.', findRichText: true), findsNothing);
    });

    testWidgets('Open the LastReel app goes to the store listing', (tester) async {
      final app = harness(web: true);
      await app.pump(tester);
      await tapText(tester, 'Open the LastReel app');
      expect(app.links.opened, [AppLinks.playStoreListing]);
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

    testWidgets('keeps the 30-day quiet and the off switch like everyone', (tester) async {
      final app = harness(desk: InMemoryDeskInviteStore(quietUntil: DateTime.utc(2026, 11, 1)), testerAllowed: true);
      await app.pump(tester);
      expect(freeSheet, findsNothing);
    }, variant: iOS);

    testWidgets('gets it once, then not again on the way back to the library', (tester) async {
      final app = harness(projects: 3, isPro: true, testerAllowed: true);
      await app.pump(tester);
      expect(proSheet, findsOneWidget);
      await tapText(tester, 'Not now');
      await visitAnotherScreen(tester);
      expect(proSheet, findsNothing);
      expect(app.desk.quietUntil, isNotNull);
    }, variant: iOS);

    testWidgets('can raise it on demand from Settings without moving its schedule', (tester) async {
      final quietUntil = DateTime.utc(2026, 11, 1);
      final app = harness(desk: InMemoryDeskInviteStore(quietUntil: quietUntil), testerAllowed: true);
      await app.pump(tester);
      expect(freeSheet, findsNothing);
      await tester.tap(find.bySemanticsLabel('Account').first);
      await tester.pumpAndSettle();
      await tapText(tester, 'Show desk invite now');
      expect(freeSheet, findsOneWidget);
      await tapText(tester, 'Not now');
      expect(app.desk.quietUntil, quietUntil);
    }, variant: iOS);

    testWidgets('still waits out the first sessions', (tester) async {
      final app = harness(desk: InMemoryDeskInviteStore(sessions: 1), testerAllowed: true);
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
