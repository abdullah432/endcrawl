import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/layout/layout_class.dart';
import 'package:lastreel/core/widgets/ec_fields.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/editor/controllers/editor_ui_controller.dart';
import 'package:lastreel/features/editor/widgets/landscape_monitor.dart';
import 'package:lastreel/features/monitor/controllers/playback_controller.dart';
import 'package:lastreel/features/project/controllers/project_controller.dart';
import 'package:lastreel/main.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

const tablet = Size(1194, 834);
const desktop = Size(1440, 900);

void main() {
  AppHarness pro() => AppHarness(
    projects: FakeProjectRepository(seed: [film()]),
    plan: FakeEntitlementRepository(const Entitlement.pro(period: BillingPeriod.yearly)),
  );

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(LastReelApp)));

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester, AppHarness app, Size size) async {
    await app.pump(tester, size: size);
    await tester.tap(find.text('The Long Way Down').first);
    await tester.pumpAndSettle();
  }

  group('breakpoints', () {
    test('a phone, a landscape tablet and a desktop browser each get their layout', () {
      expect(Breakpoints.forSize(const Size(390, 844)), LayoutClass.compact);
      expect(Breakpoints.forSize(tablet), LayoutClass.medium);
      expect(Breakpoints.forSize(const Size(834, 1194)), LayoutClass.medium);
      expect(Breakpoints.forSize(desktop), LayoutClass.expanded);
    });

    test('a phone on its side stays compact, however wide', () {
      expect(Breakpoints.forSize(const Size(932, 430)), LayoutClass.compact);
    });
  });

  group('resizing', () {
    testWidgets('keeps the open project, the selection, undo history and the playhead', (tester) async {
      final app = pro();
      await openEditor(tester, app, desktop);
      await tester.tap(find.text('Cast · two column').first);
      await tester.pumpAndSettle();

      final c = container(tester);
      final focused = c.read(editorUiControllerProvider).focusedId;
      final frame = c.read(playbackControllerProvider).frame;
      expect(focused, isNotNull);
      expect(frame, greaterThan(0));

      await tester.tap(find.byTooltip('Block actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      final blocks = c.read(projectControllerProvider).blocks.length;
      final copy = c.read(editorUiControllerProvider).focusedId;

      for (final size in [tablet, AppHarness.phone, desktop]) {
        await resize(tester, size);
        expect(c.read(projectControllerProvider).blocks.length, blocks, reason: '$size');
        expect(c.read(editorUiControllerProvider).focusedId, copy, reason: '$size');
        expect(c.read(playbackControllerProvider).frame, frame, reason: '$size');
        expect(c.read(projectControllerProvider.notifier).canUndo, isTrue, reason: '$size');
      }

      await tester.tap(find.byTooltip('Undo'));
      await tester.pumpAndSettle();
      expect(c.read(projectControllerProvider).blocks.length, blocks - 1);
    });
  });

  group('wide editor', () {
    testWidgets('the desktop block menu deletes a block and offers it back', (tester) async {
      final app = pro();
      await openEditor(tester, app, desktop);
      await tester.tap(find.text('Music cue').first);
      await tester.pumpAndSettle();
      final c = container(tester);
      final before = c.read(projectControllerProvider).blocks.length;

      await tester.tap(find.byTooltip('Block actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete block'));
      await tester.pumpAndSettle();
      expect(c.read(projectControllerProvider).blocks.length, before - 1);

      await tester.tap(find.text('Undo').last);
      await tester.pumpAndSettle();
      expect(c.read(projectControllerProvider).blocks.length, before);
    });

    testWidgets('the monitor opens full screen and Esc brings the editor back', (tester) async {
      final app = pro();
      await openEditor(tester, app, tablet);
      await tester.tap(find.byTooltip('Full screen'));
      await tester.pumpAndSettle();
      expect(find.byType(LandscapeMonitor), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(LandscapeMonitor), findsNothing);
      expect(find.text('Cast · two column'), findsWidgets);
    });

    testWidgets('space plays and pauses, but not while typing', (tester) async {
      final app = pro();
      await openEditor(tester, app, desktop);
      final c = container(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(c.read(playbackControllerProvider).playing, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(c.read(playbackControllerProvider).playing, isFalse);

      await tester.tap(find.text('Cast · two column').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextField, 'Renny').first);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(c.read(playbackControllerProvider).playing, isFalse);
    });

    testWidgets('paste on the desktop marks the line it couldn’t split', (tester) async {
      final app = pro();
      await openEditor(tester, app, desktop);
      await tester.tap(find.text('Cast · two column').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste').first);
      await tester.pumpAndSettle();

      final raw = find.descendant(of: find.byType(EcTextArea), matching: find.byType(TextField));
      await tester.enterText(raw, 'Renny — Sofia Alvarez\n\nYoung Renny Cleo Barr\nNurse — Lucia Ferrante');
      await tester.pumpAndSettle();

      final area = tester.widget<EcTextArea>(find.byType(EcTextArea));
      expect(area.lineNumbers, isTrue);
      // Blank lines count in the gutter, so the third raw line is flagged.
      expect(area.flaggedLines, {2});
    });

    testWidgets('a ready render starts from the desktop export footer', (tester) async {
      final app = pro();
      await openEditor(tester, app, desktop);
      await tester.tap(find.text('Export').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('keeps running if you close this'), findsOneWidget);

      await tester.tap(find.text('Render'));
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(app.encoder.started, hasLength(1));
    });
  });

  group('larger text', () {
    for (final (name, size) in [('tablet', tablet), ('desktop', desktop)]) {
      testWidgets('the $name library, editor, export and settings fit at 130%', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final app = pro();
        await openEditor(tester, app, size);
        await tester.tap(find.text('Cast · two column').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Export').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Projects').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('wide settings', () {
    testWidgets('a tablet opens on the plan, with the project defaults under it', (tester) async {
      final app = AppHarness(projects: FakeProjectRepository(seed: [film()]));
      await app.pump(tester, size: tablet);
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();

      expect(find.text('PLAN'), findsOneWidget);
      expect(find.text('Restore purchase'), findsOneWidget);
      expect(find.text('Frame rate'), findsOneWidget);
    });
  });
}
