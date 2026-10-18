import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/ads/data/ad_service.dart';
import 'package:lastreel/features/ads/widgets/tablet_ad.dart';
import 'package:lastreel/features/blocks/widgets/block_inspector.dart';
import 'package:lastreel/features/editor/controllers/editor_ui_controller.dart';
import 'package:lastreel/features/editor/screens/editor_screen.dart';
import 'package:lastreel/features/home/screens/tablet_home.dart';
import 'package:lastreel/features/home/tablet_layout.dart';
import 'package:lastreel/features/home/widgets/tablet_tab_bar.dart';
import 'package:lastreel/features/monitor/controllers/playback_controller.dart';
import 'package:lastreel/features/project/controllers/project_controller.dart';
import 'package:lastreel/main.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

const landscape = Size(1194, 834);
const portrait = Size(834, 1194);

void main() {
  AppHarness free({int projects = 2}) =>
      AppHarness(projects: FakeProjectRepository(seed: [for (var i = 0; i < projects; i++) film()]));
  AppHarness pro() => AppHarness(
    projects: FakeProjectRepository(seed: [film()]),
    plan: FakeEntitlementRepository(const Entitlement.pro()),
  );

  bool logged(AppHarness app, String name, Map<String, Object> params) =>
      app.analytics.events.any((e) => e.$1 == name && mapEquals(e.$2, params));

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(LastReelApp)));

  Finder ad(AdPlacement placement) =>
      find.byWidgetPredicate((w) => w is TabletAdPlaceholder && w.placement == placement);

  group('when the tablet layout applies', () {
    testWidgets('a landscape or portrait tablet gets the tabs; a phone does not', (tester) async {
      await free().pump(tester, size: landscape);
      expect(find.byType(TabletHome), findsOneWidget);
      expect(find.byType(TabletTabBar), findsNothing);

      tester.view.physicalSize = portrait;
      await tester.pumpAndSettle();
      expect(find.byType(TabletHome), findsOneWidget);
      expect(find.byType(TabletTabBar), findsOneWidget);

      tester.view.physicalSize = AppHarness.phone;
      await tester.pumpAndSettle();
      expect(find.byType(TabletHome), findsNothing);
    });

    testWidgets('the web build keeps its own layout at tablet sizes', (tester) async {
      final app = AppHarness(
        projects: FakeProjectRepository(seed: [film()]),
        plan: FakeEntitlementRepository(const Entitlement.pro()),
        web: true,
      );
      await app.pump(tester, size: landscape);
      expect(find.byType(TabletHome), findsNothing);
    });

    testWidgets('says which orientation it is shown in', (tester) async {
      final app = free();
      await app.pump(tester, size: landscape);
      tester.view.physicalSize = portrait;
      await tester.pumpAndSettle();
      final shown = [
        for (final (name, params) in app.analytics.events)
          if (name == 'tablet_layout_shown') params['orientation'],
      ];
      expect(shown, ['landscape', 'portrait']);
    });
  });

  group('Settings is a tab', () {
    testWidgets('the rail stays, there is no back button, and the plan leads', (tester) async {
      final app = free();
      await app.pump(tester, size: landscape);
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();

      expect(find.byType(TabletHome), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing);
      expect(find.text('Privacy & data'), findsOneWidget);
      expect(find.text('Restore purchase'), findsOneWidget);
      expect(logged(app, 'nav_tab_selected', {'tab': 'settings', 'from': 'projects'}), isTrue);
    });

    testWidgets('picking a section swaps only the detail and is remembered across rotation', (tester) async {
      final app = free();
      await app.pump(tester, size: landscape);
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Privacy & data'));
      await tester.pumpAndSettle();
      expect(find.text('Stored with your account'.toUpperCase()), findsOneWidget);
      expect(logged(app, 'settings_section_opened', {'section': 'privacy'}), isTrue);
      // The list and its ad stay put.
      expect(ad(AdPlacement.settings), findsOneWidget);

      tester.view.physicalSize = portrait;
      await tester.pumpAndSettle();
      expect(find.text('What we keep, and what you control.'), findsOneWidget);
      // A section's detail never shows an ad.
      expect(ad(AdPlacement.settings), findsNothing);

      await tester.tap(find.bySemanticsLabel('Back to Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Defaults for new projects'), findsOneWidget);
      expect(ad(AdPlacement.settings), findsOneWidget);
    });

    testWidgets('Pro shows no ad in Settings', (tester) async {
      await pro().pump(tester, size: landscape);
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      expect(find.byType(TabletAdCard), findsNothing);
    });
  });

  group('ads on Free', () {
    for (final count in [0, 1, 2]) {
      testWidgets('the library foot strip shows at $count of 2', (tester) async {
        await free(projects: count).pump(tester, size: landscape);
        expect(ad(AdPlacement.library), findsOneWidget);
        if (count == 2) expect(find.text('Both free projects are in use.'), findsOneWidget);
        if (count < 2) expect(find.text('${2 - count} free slot${count == 1 ? '' : 's'} left'), findsOneWidget);
      });
    }

    testWidgets('one ad on screen at most, and none on Pro', (tester) async {
      final app = free();
      await app.pump(tester, size: landscape);
      expect(find.byType(TabletAdCard), findsOneWidget);
      // The hidden tab asks for no ad of its own.
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      expect(find.byType(TabletAdCard), findsOneWidget);
      expect(ad(AdPlacement.settings), findsOneWidget);
      expect(app.ads.requested.map((r) => r.$1).toSet(), {AdPlacement.library, AdPlacement.settings});

      await pro().pump(tester, size: portrait);
      expect(find.byType(TabletAdCard), findsNothing);
    });

    testWidgets('Remove ads opens the Pro screen and says where it came from', (tester) async {
      final app = free();
      await app.pump(tester, size: landscape);
      await tester.tap(find.text('Remove ads').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('LASTREEL PRO'), findsOneWidget);
      expect(logged(app, 'remove_ads_tapped', {'slot': 'library_foot'}), isTrue);
    });
  });

  group('editor and Settings', () {
    testWidgets('the editor shows neither the rail nor the tab bar', (tester) async {
      await pro().pump(tester, size: portrait);
      await tester.tap(find.text('The Long Way Down').first);
      await tester.pumpAndSettle();
      expect(find.byType(EditorScreen), findsOneWidget);
      expect(find.byType(TabletTabBar).hitTestable(), findsNothing);
    });

    testWidgets('the account button lands on Plan, and the same card resumes the edit', (tester) async {
      final app = pro();
      await app.pump(tester, size: landscape);
      await tester.tap(find.text('The Long Way Down').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cast · two column').first);
      await tester.pumpAndSettle();
      final c = container(tester);
      final frame = c.read(playbackControllerProvider).frame;
      c.read(projectControllerProvider.notifier).renameProject('Kept in memory');
      c.read(projectControllerProvider.notifier).duplicateBlock('dir');
      c.read(settingsSectionProvider.notifier).select(SettingsSection.legal);

      await tester.tap(find.byTooltip('Settings and account'));
      await tester.pumpAndSettle();
      expect(find.byType(EditorScreen), findsNothing);
      expect(c.read(homeTabProvider).name, 'settings');
      expect(c.read(settingsSectionProvider), SettingsSection.plan);
      expect(find.text('PLAN'), findsWidgets);
      expect(logged(app, 'nav_tab_selected', {'tab': 'settings', 'from': 'editor'}), isTrue);

      await tester.tap(find.text('Projects').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kept in memory').first);
      await tester.pumpAndSettle();
      expect(find.byType(EditorScreen), findsOneWidget);
      expect(c.read(editorUiControllerProvider).focusedId, 'cst');
      expect(c.read(playbackControllerProvider).frame, frame);
      expect(c.read(projectControllerProvider.notifier).canUndo, isTrue);
    });
  });

  group('library and editor details', () {
    testWidgets('the project menu offers Export…, which opens the editor on export', (tester) async {
      await pro().pump(tester, size: landscape);
      await tester.tap(find.byTooltip('Project actions').first);
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      await tester.tap(find.text('Export…'));
      await tester.pumpAndSettle();
      // The export page sits over the editor it opened.
      expect(find.byType(EditorScreen, skipOffstage: false), findsOneWidget);
      expect(find.text('Render the roll.'), findsOneWidget);
    });

    testWidgets('in portrait the selected block opens in place in the list', (tester) async {
      await pro().pump(tester, size: portrait);
      await tester.tap(find.text('The Long Way Down').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cast · two column').first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byWidgetPredicate((w) => w is BlockInspector && w.inline), findsOneWidget);
      expect(find.text('Sofia Alvarez'), findsWidgets);
    });
  });
}
