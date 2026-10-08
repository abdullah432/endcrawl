import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/features/cookoo/data/cookoo_contact_client.dart';
import 'package:lastreel/features/cookoo/data/cookoo_store.dart';
import 'package:lastreel/features/cookoo/screens/cookoo_contact_screen.dart';
import 'package:lastreel/features/cookoo/screens/cookoo_sent_screen.dart';
import 'package:lastreel/features/cookoo/widgets/cookoo_swiper.dart';

import '../../support/app_harness.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  late AppHarness app;

  setUp(() => app = AppHarness(projects: FakeProjectRepository(seed: [film()])));

  /// Taps the copy of [text] that is on screen — the swiper also builds the
  /// slides either side of the current one.
  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).hitTestable().first);
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await app.pump(tester);
    await tester.tap(find.bySemanticsLabel('Account').first);
    await tester.pumpAndSettle();
  }

  Future<void> swipeNext(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
  }

  Switch studioSwitch(WidgetTester tester) => tester.widget<Switch>(
    find.descendant(
      of: find.ancestor(of: find.text('Show COOKOO studio card'), matching: find.byType(InkWell)).first,
      matching: find.byType(Switch),
    ),
  );

  Future<void> fillForm(WidgetTester tester, {String email = 'amira@mail.com'}) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Amira');
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), 'An app for booking driving lessons');
    await tester.pumpAndSettle();
  }

  /// The parameters of the one [event] logged.
  Map<String, Object> params(String event) => app.analytics.events.singleWhere((e) => e.$1 == event).$2;

  bool sendEnabled(WidgetTester tester) =>
      tester
          .widget<InkWell>(find.ancestor(of: find.text('Send my idea'), matching: find.byType(InkWell)).first)
          .onTap !=
      null;

  group('studio card in Settings', () {
    testWidgets('sits under the plan card, opens on slide 1 and reports it once', (tester) async {
      await openSettings(tester);
      expect(find.text('FROM THE MAKERS OF LASTREEL'), findsOneWidget);
      expect(find.text('We build apps people use and pay for.'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(CookooSwiper)).dy,
        lessThan(tester.getTopLeft(find.text('DEFAULTS FOR NEW PROJECTS')).dy),
      );
      expect(app.analytics.names.where((n) => n == 'cookoo_card_view'), hasLength(1));

      await swipeNext(tester);
      expect(find.bySemanticsLabel(RegExp('Slide 2 of 4')), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await tester.pumpAndSettle();
      // Back on slide 1: swiped twice, but slide 1 was already seen.
      expect(app.analytics.names.where((n) => n == 'cookoo_card_swipe'), hasLength(2));
      expect(
        [
          for (final (name, p) in app.analytics.events)
            if (name == 'cookoo_card_view') p['slide'],
        ],
        ['s1', 's2'],
      );
    });

    testWidgets('a case study opens on cookoo.dev, tagged with the app', (tester) async {
      await openSettings(tester);
      await swipeNext(tester);
      await tapText(tester, 'SEE THE FULL STORY · COOKOO.DEV/CASES');
      expect(app.links.opened, [Uri.parse('https://cookoo.dev/cases/planformer?from=lastreel')]);
      expect(app.analytics.names, contains('cookoo_site_open'));
    });

    testWidgets('Hide is saved at once and can be undone this session', (tester) async {
      await openSettings(tester);
      await tester.tap(find.bySemanticsLabel('Hide the COOKOO card'));
      await tester.pumpAndSettle();
      expect(app.cookoo.promoHidden, isTrue);
      expect(find.byType(PageView), findsNothing);
      expect(find.text('Hidden. You can turn it back on below.'), findsOneWidget);
      expect(studioSwitch(tester).value, isFalse);
      expect(app.analytics.names, contains('cookoo_card_hide'));

      await tapText(tester, 'Undo');
      expect(app.cookoo.promoHidden, isFalse);
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('once hidden it stays away, until the switch turns it back on', (tester) async {
      app = AppHarness(
        projects: FakeProjectRepository(seed: [film()]),
        cookoo: InMemoryCookooStore(promoHidden: true),
      );
      await openSettings(tester);
      expect(find.byType(PageView), findsNothing);
      expect(find.text('Hidden. You can turn it back on below.'), findsNothing);

      await tapText(tester, 'Show COOKOO studio card');
      expect(app.cookoo.promoHidden, isFalse);
      expect(find.byType(PageView), findsOneWidget);
    });
  });

  group('contact', () {
    testWidgets('sends once name, a valid email and the idea are in, then confirms', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Tell us your idea');
      expect(find.byType(CookooContactScreen), findsOneWidget);
      expect(params('cookoo_cta_tap'), {'source': 's1'});
      expect(sendEnabled(tester), isFalse);

      await fillForm(tester, email: 'amira@mail');
      expect(sendEnabled(tester), isFalse);
      await tester.enterText(find.byType(TextField).at(1), 'amira@mail.com');
      await tapText(tester, r'$5,000–$15,000');
      expect(sendEnabled(tester), isTrue);

      await tapText(tester, 'Send my idea');
      final sent = app.contact.sent.single;
      expect(sent['need'], 'new_app');
      expect(sent['budget'], '5k_15k');
      expect(sent['name'], 'Amira');
      expect(sent['email'], 'amira@mail.com');
      expect(sent['source'], 'lastreel_settings_s1');
      expect(params('cookoo_contact_submit'), {'need': 'new_app', 'budget': '5k_15k', 'source': 's1'});

      expect(find.byType(CookooSentScreen), findsOneWidget);
      expect(find.text('Got it, Amira.'), findsOneWidget);
      expect(find.text('YOUR IDEA · A NEW APP'), findsOneWidget);
      await tapText(tester, 'Back to LastReel');
      expect(find.byType(CookooSwiper), findsOneWidget);
    });

    testWidgets('offline, the idea is queued and goes out on the next try', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Tell us your idea');
      await fillForm(tester);
      app.contact.next = CookooDelivery.retry;
      await tapText(tester, 'Send my idea');

      expect(find.byType(CookooSentScreen), findsOneWidget);
      expect(find.textContaining('back online'), findsOneWidget);
      expect(app.contact.sent, isEmpty);
      final queued = jsonDecode(app.cookoo.pendingContacts.single) as Map<String, Object?>;
      expect(queued['email'], 'amira@mail.com');

      app.contact.next = CookooDelivery.sent;
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(app.contact.sent.single['email'], 'amira@mail.com');
      expect(app.cookoo.pendingContacts, isEmpty);
    });

    testWidgets('a refused request stays on the form', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Tell us your idea');
      await fillForm(tester);
      app.contact.next = CookooDelivery.rejected;
      await tapText(tester, 'Send my idea');
      expect(find.byType(CookooContactScreen), findsOneWidget);
      expect(find.byType(CookooSentScreen), findsNothing);
      expect(app.cookoo.pendingContacts, isEmpty);
    });

    testWidgets('the website link opens the case list', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Tell us your idea');
      await tapText(tester, 'See our work on cookoo.dev');
      expect(app.links.opened, [Uri.parse('https://cookoo.dev/cases?from=lastreel')]);
    });
  });
}
