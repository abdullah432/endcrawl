import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:endcrawl/main.dart';

void main() {
  // A portrait phone-sized surface — the default test surface (800x600) is
  // landscape, which would exercise the rotate-to-preview full-bleed
  // monitor instead of the normal editor UI these tests check.
  Future<void> setPortraitSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('App boots to the templates screen', (WidgetTester tester) async {
    await setPortraitSurface(tester);
    await tester.pumpWidget(const ProviderScope(child: EndcrawlApp()));
    await tester.pump();

    expect(find.text('ENDCRAWL'), findsOneWidget);
    expect(find.text('Pick a starting point.\nChange anything later.'), findsOneWidget);
    expect(find.text('Short Film'), findsOneWidget);
  });

  testWidgets('Picking a template opens the format screen', (WidgetTester tester) async {
    await setPortraitSurface(tester);
    await tester.pumpWidget(const ProviderScope(child: EndcrawlApp()));
    await tester.pump();

    await tester.tap(find.text('Short Film'));
    await tester.pumpAndSettle();

    expect(find.text('Canvas format'), findsOneWidget);
  });

  testWidgets('Opening the editor renders the monitor and block list', (WidgetTester tester) async {
    await setPortraitSurface(tester);
    await tester.pumpWidget(const ProviderScope(child: EndcrawlApp()));
    await tester.pump();

    await tester.tap(find.text('Short Film'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    expect(find.textContaining('blocks · drag to reorder'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
  });

  testWidgets('Add block sheet opens and adds a title card to an empty project', (WidgetTester tester) async {
    await setPortraitSurface(tester);
    await tester.pumpWidget(const ProviderScope(child: EndcrawlApp()));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Start empty'), 300);
    await tester.tap(find.text('Start empty'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();

    expect(find.text('No blocks yet'), findsOneWidget);

    await tester.tap(find.text('Add first block'));
    await tester.pumpAndSettle();
    expect(find.text('Title card'), findsOneWidget);

    await tester.tap(find.text('Title card'));
    await tester.pumpAndSettle();

    expect(find.text('No blocks yet'), findsNothing);
    expect(find.textContaining('1 blocks · drag to reorder'), findsOneWidget);
  });

  Future<void> openShortFilmEditor(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EndcrawlApp()));
    await tester.pump();
    await tester.tap(find.text('Short Film'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
  }

  testWidgets('Timing sheet opens and shows the judder/readability cards', (WidgetTester tester) async {
    await setPortraitSurface(tester);
    await openShortFilmEditor(tester);

    await tester.tap(find.text('Timing'));
    await tester.pumpAndSettle();

    expect(find.text('Lock runtime'), findsOneWidget);
    expect(find.text('Head black'), findsOneWidget);
  });

  testWidgets('Paste & split sheet opens and parses the seed cast list', (WidgetTester tester) async {
    await setPortraitSurface(tester);
    await openShortFilmEditor(tester);

    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();

    expect(find.text('Paste & split'), findsOneWidget);
    expect(find.textContaining('Add '), findsWidgets);
  });

  testWidgets('Export sheet opens on the idle/locked-settings state', (WidgetTester tester) async {
    await setPortraitSurface(tester);
    await openShortFilmEditor(tester);

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(find.text('LOCKED FOR THIS RENDER'), findsOneWidget);
    expect(find.text('ProRes 4444'), findsWidgets);
  });

  testWidgets('Tapping the cast block card opens the cast editor with its rows', (WidgetTester tester) async {
    await setPortraitSurface(tester);
    await openShortFilmEditor(tester);

    await tester.scrollUntilVisible(find.text('Cast'), 300);
    await tester.tap(find.text('Cast'));
    await tester.pumpAndSettle();

    expect(find.text('Centre gutter'), findsOneWidget);
    expect(find.text('FAST ENTRY — NEXT HOPS ROLE → NAME → NEW ROW'), findsOneWidget);
  });

  testWidgets('Select mode shows the bulk action bar', (WidgetTester tester) async {
    await setPortraitSurface(tester);
    await openShortFilmEditor(tester);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('Restyle'), findsOneWidget);
  });

  testWidgets('Rotating to landscape shows the full-bleed monitor', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openShortFilmEditor(tester);

    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();

    expect(find.textContaining('FULL-BLEED MONITOR'), findsOneWidget);
  });
}
