import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/config/app_links.dart';
import 'package:lastreel/features/settings/screens/settings_screen.dart';

import '../../support/app_harness.dart';

void main() {
  Future<void> openSettings(WidgetTester tester, AppHarness app, {Size size = AppHarness.phone}) async {
    await app.pump(tester, size: size);
    await tester.tap(find.bySemanticsLabel('Account').first);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  }

  testWidgets('7.1 — our other apps, each opening its Google Play page', (tester) async {
    final app = AppHarness();
    await openSettings(tester, app);
    final textCrawl = find.bySemanticsLabel('Get TextCrawl on Google Play');
    await tester.scrollUntilVisible(textCrawl, 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('EXPLORE OUR OTHER APPS'), findsOneWidget);
    expect(find.text('AKS'), findsOneWidget);

    await tester.tap(textCrawl);
    await tester.tap(find.bySemanticsLabel('Get AKS on Google Play'));
    expect(app.links.opened, [AppLinks.textCrawlListing, AppLinks.aksListing]);
  });

  testWidgets('on a tablet they sit under the COOKOO tile, in From the makers', (tester) async {
    final app = AppHarness();
    await app.pump(tester, size: const Size(1194, 834));
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Support'));
    await tester.pumpAndSettle();
    expect(find.text('Help centre'), findsOneWidget);
    expect(find.text('TextCrawl'), findsNothing);

    await tester.tap(find.text('From the makers'));
    await tester.pumpAndSettle();
    expect(find.text('FROM THE MAKERS OF LASTREEL'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);
    expect(find.text('TextCrawl'), findsOneWidget);
  });

  testWidgets('P7.1: upright, From the makers sits on the Settings page, two tiles across', (tester) async {
    final app = AppHarness();
    await app.pump(tester, size: const Size(834, 1194));
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    // No section row for it: the tiles are on the page.
    expect(find.text('From the makers'), findsNothing);
    final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
    await tester.scrollUntilVisible(find.text('FROM THE MAKERS OF LASTREEL'), 200, scrollable: page);
    await tester.pumpAndSettle();
    expect(find.text('1–2 of 4'), findsOneWidget);
    // An impression, for Google Analytics' Promotions report too.
    expect(app.analytics.names, containsAll(['cookoo_card_view', 'view_promotion']));
    final promo = app.analytics.events.firstWhere((e) => e.$1 == 'view_promotion').$2;
    expect(promo['location_id'], 'tablet_portrait');

    await tester.scrollUntilVisible(find.text('TextCrawl'), 200, scrollable: page);
    await tester.tap(find.bySemanticsLabel('Get TextCrawl on Google Play'));
    expect(app.analytics.names, contains('cookoo_other_app_tap'));
    expect(app.links.opened.single.queryParameters['referrer'], contains('utm_source=lastreel'));
  });
}
