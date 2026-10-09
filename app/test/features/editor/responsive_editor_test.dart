import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/layout/adaptive_layout.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/editor/controllers/editor_ui_controller.dart';
import 'package:lastreel/features/editor/widgets/block_row.dart';
import 'package:lastreel/features/monitor/controllers/playback_controller.dart';
import 'package:lastreel/features/project/controllers/project_controller.dart';
import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  test('content breakpoints are centralized', () {
    for (final (width, layout) in [
      (599.0, EcLayout.compact),
      (600.0, EcLayout.spacious),
      (767.0, EcLayout.spacious),
      (768.0, EcLayout.tablet),
      (1279.0, EcLayout.tablet),
      (1280.0, EcLayout.desktop),
    ]) {
      expect(layoutForWidth(width), layout);
    }
  });

  for (final size in [
    const Size(768, 1024),
    const Size(834, 1194),
    const Size(1194, 834),
    const Size(1279, 700),
    const Size(1280, 700),
    const Size(1440, 900),
    const Size(1440, 500),
  ]) {
    testWidgets('editor tools remain usable at $size', (tester) async {
      final app = AppHarness(
        projects: FakeProjectRepository(seed: [film()]),
        plan: FakeEntitlementRepository(const Entitlement.pro()),
      );
      await app.pump(tester, size: size);
      await tester.tap(find.text('The Long Way Down'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Select a block to edit'), findsOneWidget);
      await tester.ensureVisible(
        find.byWidgetPredicate((w) => w is BlockRow && w.block.id == 'cst'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate((w) => w is BlockRow && w.block.id == 'cst'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Sofia Alvarez'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Timing'));
      await tester.pumpAndSettle();
      expect(find.text('Lock runtime'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(834, 500), const Size(1440, 500)]) {
    testWidgets('short panes support enlarged text at $size', (tester) async {
      final app = AppHarness(
        projects: FakeProjectRepository(seed: [film()]),
        plan: FakeEntitlementRepository(const Entitlement.pro()),
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await app.pump(tester, size: size);
      await tester.tap(find.text('The Long Way Down'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byWidgetPredicate((w) => w is BlockRow && w.block.id == 'cst'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate((w) => w is BlockRow && w.block.id == 'cst'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [599.0, 600.0, 767.0, 768.0]) {
    testWidgets('single-column boundary remains editable at $width', (
      tester,
    ) async {
      final app = AppHarness(projects: FakeProjectRepository(seed: [film()]));
      await app.pump(tester, size: Size(width, 900));
      await tester.tap(find.text('The Long Way Down'));
      await tester.pumpAndSettle();
      final row = find.byWidgetPredicate(
        (w) => w is BlockRow && w.block.id == 'cst',
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Sofia Alvarez'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tablet form keeps its draft with keyboard insets', (
    tester,
  ) async {
    final app = AppHarness(projects: FakeProjectRepository(seed: [film()]));
    await app.pump(tester, size: const Size(834, 1194));
    await tester.tap(find.text('The Long Way Down'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => w is BlockRow && w.block.id == 'cst'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Keyboard draft');
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Keyboard draft'));
    expect(find.text('Keyboard draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resize preserves form draft, selection, document and playback', (
    tester,
  ) async {
    final app = AppHarness(projects: FakeProjectRepository(seed: [film()]));
    await app.pump(tester, size: const Size(1194, 834));
    await tester.tap(find.text('The Long Way Down'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate((w) => w is BlockRow && w.block.id == 'cst'),
    );
    await tester.pumpAndSettle();
    final scope = ProviderScope.containerOf(
      tester.element(find.text('Projects').first),
    );
    final drafts = find.byType(TextField);
    await tester.enterText(drafts.last, 'Unsubmitted actor');
    final document = scope.read(projectControllerProvider).project;
    final position = scope.read(playbackControllerProvider).frame;
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(find.text('Unsubmitted actor'), findsOneWidget);
    expect(scope.read(editorUiControllerProvider).focusedId, 'cst');
    expect(scope.read(projectControllerProvider).project, document);
    expect(scope.read(playbackControllerProvider).frame, position);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(
      scope.read(playbackControllerProvider).playing,
      isFalse,
      reason: 'typing must not invoke playback',
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.text('Unsubmitted actor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
