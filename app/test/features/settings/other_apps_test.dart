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
}
