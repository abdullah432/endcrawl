import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/domain/models/credit_block.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/domain/models/project.dart';
import 'package:lastreel/domain/models/render_summary.dart';
import 'package:lastreel/features/editor/screens/editor_screen.dart';
import 'package:lastreel/features/editor/widgets/block_row.dart';
import 'package:lastreel/features/plan/controllers/editable_projects.dart';
import 'package:lastreel/features/project/controllers/project_controller.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';

Project _project(String title, int day) => Project.create(
      title: title,
      now: DateTime.utc(2026, 9, day),
      blocks: const [NameListBlock(id: 'dir', header: 'Directed by', names: ['Maya Okonkwo'])],
    );

void main() {
  // After a trial ends: three projects, Free again. "Salt Flats" was edited
  // last, so it's the one that stays editable.
  final older = _project('The Long Way Down', 1);
  final middle = _project('Night Shift', 2);
  final newest = _project('Salt Flats', 3);

  AppHarness lapsed({Entitlement plan = const Entitlement.free(lapsed: true)}) => AppHarness(
        projects: FakeProjectRepository(seed: [older, middle, newest]),
        plan: FakeEntitlementRepository(plan),
      );

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

  testWidgets('every project stays; only the most recently edited one is editable', (tester) async {
    final app = lapsed();
    await app.pump(tester);

    expect(find.text('The Long Way Down'), findsOneWidget);
    expect(find.text('Night Shift'), findsOneWidget);
    expect(find.text('Salt Flats'), findsOneWidget);
    expect(find.text('READ-ONLY'), findsNWidgets(2));
    expect(container(tester).read(readOnlyProjectIdsProvider), {older.id, middle.id});
    expect(find.text('REEL · 3 · FREE'), findsOneWidget);
  });

  testWidgets('a read-only project opens to play and export, but refuses edits', (tester) async {
    final app = lapsed();
    await app.pump(tester);
    await tapText(tester, 'Night Shift');
    expect(find.byType(EditorScreen), findsOneWidget);

    expect(find.text('Read-only on the free plan'), findsOneWidget);
    expect(find.text('Edit this one instead'), findsOneWidget);
    expect(find.text('Try Pro free'), findsOneWidget);
    expect(find.text('Select'), findsNothing);

    await tester.tap(find.byType(BlockRow).first);
    await tester.pumpAndSettle();
    expect(find.text('Read-only on the free plan — one project stays editable'), findsOneWidget);

    final controller = container(tester).read(projectControllerProvider.notifier);
    controller.renameProject('Renamed');
    controller.addBlock(const SpacerBlock(id: 'gap'));
    await tester.pump(const Duration(seconds: 3));
    final stored = app.projects.projects[middle.id]!;
    expect(stored.title, 'Night Shift');
    expect(stored.blocks, hasLength(1));
    expect(stored.updatedAt, middle.updatedAt);

    // Rendering is allowed, and doesn't make it the editable one.
    await controller.recordRender(
      RenderSummary(outcome: RenderOutcome.rendered, codec: 'H.264', width: 1920, height: 1080, at: app.now),
    );
    await tester.pumpAndSettle();
    expect(app.projects.projects[middle.id]!.lastRender?.outcome, RenderOutcome.rendered);
    expect(container(tester).read(readOnlyProjectIdsProvider), contains(middle.id));
  });

  testWidgets('"Edit this one instead" swaps which project is editable', (tester) async {
    final app = lapsed();
    await app.pump(tester);
    await tapText(tester, 'Night Shift');

    await tapText(tester, 'Edit this one instead');
    await tapText(tester, 'Edit this one');

    expect(find.text('Read-only on the free plan'), findsNothing);
    expect(container(tester).read(readOnlyProjectIdsProvider), {older.id, newest.id});
    expect(app.projects.projects[middle.id]!.updatedAt.isAfter(newest.updatedAt), isTrue);
  });

  testWidgets('renaming a read-only project from the library is refused', (tester) async {
    final app = lapsed();
    await app.pump(tester);
    await tester.tap(find.byTooltip('Project actions').last); // the oldest card
    await tester.pumpAndSettle();
    await tapText(tester, 'Rename');
    await tester.enterText(find.byType(TextField), 'New name');
    await tester.pump();
    await tapText(tester, 'Save');

    expect(find.text('Read-only on the free plan — one project stays editable.'), findsOneWidget);
    expect(app.projects.projects[older.id]!.title, 'The Long Way Down');
  });

  testWidgets('on Pro or a trial, everything is editable', (tester) async {
    final app = lapsed(plan: Entitlement.pro(trialEndsAt: DateTime.utc(2026, 9, 30)));
    await app.pump(tester);
    expect(find.text('READ-ONLY'), findsNothing);
    expect(container(tester).read(readOnlyProjectIdsProvider), isEmpty);
  });
}
