import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/domain/models/render_summary.dart';
import 'package:lastreel/features/ads/data/ad_service.dart';
import 'package:lastreel/features/ads/widgets/tablet_ad.dart';
import 'package:lastreel/features/export/data/video_encoder.dart';
import 'package:lastreel/features/export/screens/tablet_render_page.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

const landscape = Size(1194, 834);
const portrait = Size(834, 1194);

void main() {
  AppHarness harness({Entitlement plan = const Entitlement.free()}) => AppHarness(
    projects: FakeProjectRepository(
      seed: [
        film(),
        film().copyWith(
          title: 'Salt Flats',
          lastRender: RenderSummary(
            outcome: RenderOutcome.rendered,
            codec: 'H.264',
            width: 1920,
            height: 1080,
            at: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ),
      ],
    ),
    plan: FakeEntitlementRepository(plan),
  );

  Finder renderAd() =>
      find.byWidgetPredicate((w) => w is TabletAdPlaceholder && w.placement == AdPlacement.rendering);

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> startRender(WidgetTester tester, AppHarness app, Size size) async {
    await app.pump(tester, size: size);
    await tap(tester, 'The Long Way Down');
    await tap(tester, 'Export');
    await tester.tap(find.text('Render').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> finish(WidgetTester tester) async {
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('rendering: the monitor, progress, the wait ad and the renders list', (tester) async {
    final app = harness();
    await startRender(tester, app, landscape);
    expect(find.byType(TabletRenderPage), findsOneWidget);
    expect(find.text('Rendering…'), findsOneWidget);
    expect(find.text('H.264 · 1920 × 1080'), findsOneWidget);
    expect(find.text('Keep working · renders in background'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(renderAd(), findsOneWidget);
    // The renders list sits beside the progress, with other projects' last
    // renders.
    expect(find.text('RENDERS'), findsOneWidget);
    expect(find.text('Salt Flats'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('RENDERS')).dx,
      greaterThan(tester.getTopRight(find.text('Rendering…')).dx),
    );

    await finish(tester);
    expect(find.text('Rendered.'), findsOneWidget);
    // The ad is the wait's: gone once the render ends.
    expect(renderAd(), findsNothing);
    await tap(tester, 'Save to device');
    expect(app.destinations.savedToPhotos, hasLength(1));
    await tap(tester, 'Share');
    expect(app.destinations.shared, hasLength(1));
  });

  testWidgets('Keep working closes the page and the render carries on', (tester) async {
    final app = harness();
    app.encoder.frameTime = const Duration(milliseconds: 200);
    await startRender(tester, app, landscape);
    await tap(tester, 'Keep working · renders in background');
    expect(find.byType(TabletRenderPage), findsNothing);
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();
    expect(app.encoder.started, hasLength(1));
    expect(app.encoder.appended, 48);
  });

  testWidgets('a failure says why, and Retry render starts again', (tester) async {
    final app = harness();
    app.encoder
      ..failWith = const EncoderException.outOfSpace()
      ..failAtFrame = 12;
    await startRender(tester, app, landscape);
    await finish(tester);
    expect(find.text('Stopped.'), findsOneWidget);
    expect(find.text('Stopped at frame 12 · not enough storage'), findsOneWidget);
    expect(find.textContaining('Nothing in the project changed.'), findsOneWidget);
    expect(renderAd(), findsNothing);
    await tap(tester, 'Retry render');
    expect(app.encoder.started, hasLength(2));
    await finish(tester);
    expect(find.text('Rendered.'), findsOneWidget);
  });

  testWidgets('portrait stacks the renders under the progress, actions in each row', (tester) async {
    final app = harness();
    await startRender(tester, app, portrait);
    expect(renderAd(), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('RENDERS')).dy,
      greaterThan(tester.getBottomLeft(find.text('Keep working · renders in background')).dy),
    );
    await finish(tester);
    await tap(tester, 'Save');
    expect(app.destinations.savedToPhotos, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Pro sees the progress card alone', (tester) async {
    final app = harness(plan: const Entitlement.pro());
    await startRender(tester, app, landscape);
    expect(find.text('Rendering…'), findsOneWidget);
    expect(find.byType(TabletAdCard), findsNothing);
    expect(renderAd(), findsNothing);
    await finish(tester);
  });

  testWidgets('a cancelled render goes back to the settings', (tester) async {
    final app = harness();
    app.encoder.frameTime = const Duration(milliseconds: 200);
    await startRender(tester, app, landscape);
    await tap(tester, 'Cancel');
    expect(find.byType(TabletRenderPage), findsNothing);
    expect(find.text('Render the roll.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('the page fits with larger text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final app = harness();
    await startRender(tester, app, landscape);
    expect(tester.takeException(), isNull);
    await finish(tester);
    expect(find.text('Rendered.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
