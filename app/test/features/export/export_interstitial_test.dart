import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/export/controllers/export_controller.dart';
import 'package:lastreel/features/export/data/video_encoder.dart';
import 'package:lastreel/features/export/models/export_models.dart';
import 'package:lastreel/features/export/screens/export_sheet.dart';
import 'package:lastreel/features/editor/screens/editor_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  late AppHarness app;
  final mobile = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
  });
  setUp(
    () => app = AppHarness(projects: FakeProjectRepository(seed: [film()])),
  );

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> open(
    WidgetTester tester, {
    bool openExport = true,
  }) async {
    await app.pump(tester);
    await tap(tester, 'The Long Way Down');
    if (openExport) await tap(tester, 'Export');
    return ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
  }

  Future<void> finish(WidgetTester tester) async {
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'preloads while editing and shows once a render succeeds, not on Export',
    (tester) async {
      await open(tester, openExport: false);
      expect(app.ads.exportInterstitialPreloaded, greaterThanOrEqualTo(1));
      await tap(tester, 'Export');
      expect(app.ads.exportInterstitialShown, 0);
      expect(find.byType(ExportSheet), findsOneWidget);
      await tap(tester, 'Render H.264');
      expect(app.ads.exportInterstitialShown, 0);
      await finish(tester);
      expect(app.ads.exportInterstitialShown, 1);
      await tap(tester, 'Save to Files');
      expect(app.destinations.shared, hasLength(1));
      await tester.pumpAndSettle();
      expect(app.ads.exportInterstitialShown, 1);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tap(tester, 'Export');
      expect(app.ads.exportInterstitialShown, 1);
      await tap(tester, 'Render H.264');
      await finish(tester);
      expect(app.ads.exportInterstitialShown, 2);
    },
    variant: mobile,
  );

  testWidgets('a failure shows none; its successful retry shows one', (
    tester,
  ) async {
    app.encoder.failWith = const EncoderException(
      EncoderFailureKind.failed,
      'Encoder failed',
    );
    final container = await open(tester);
    await tap(tester, 'Render H.264');
    await finish(tester);
    expect(
      container.read(exportControllerProvider).run?.phase,
      ExportPhase.failed,
    );
    expect(app.ads.exportInterstitialShown, 0);
    container.read(exportControllerProvider.notifier).retry();
    await finish(tester);
    expect(
      container.read(exportControllerProvider).run?.phase,
      ExportPhase.done,
    );
    expect(app.ads.exportInterstitialShown, 1);
  }, variant: mobile);

  testWidgets('cancellation shows no interstitial', (tester) async {
    final container = await open(tester);
    await tap(tester, 'Render H.264');
    container.read(exportControllerProvider.notifier).cancel();
    await finish(tester);
    expect(app.ads.exportInterstitialShown, 0);
  }, variant: mobile);

  testWidgets(
    'ad errors cannot change successful output into a failed render',
    (tester) async {
      app.ads.exportInterstitialFailure = StateError('SDK unavailable');
      final container = await open(tester);
      await tap(tester, 'Render H.264');
      await finish(tester);
      expect(app.ads.exportInterstitialShown, 1);
      expect(
        container.read(exportControllerProvider).run?.phase,
        ExportPhase.done,
      );
      expect(find.text('Save to Files'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: mobile,
  );

  testWidgets('the ready screen stays usable while the ad is up', (
    tester,
  ) async {
    final dismissed = Completer<void>();
    app.ads.exportInterstitialCompletion = dismissed.future;
    await open(tester);
    await tap(tester, 'Render H.264');
    await finish(tester);
    expect(app.ads.exportInterstitialShown, 1);
    expect(find.text('Save to Files'), findsOneWidget);
    dismissed.complete();
    await tester.pumpAndSettle();
    expect(find.text('Save to Files'), findsOneWidget);
  }, variant: mobile);

  testWidgets('Pro exports never preload or show the interstitial', (
    tester,
  ) async {
    app.plan = FakeEntitlementRepository(const Entitlement.pro());
    await open(tester);
    await tap(tester, 'Render H.264');
    await finish(tester);
    expect(app.ads.exportInterstitialPreloaded, 0);
    expect(app.ads.exportInterstitialShown, 0);
  }, variant: mobile);

  testWidgets('upgrading before the render ends suppresses the ad', (
    tester,
  ) async {
    await open(tester);
    app.plan.entitlement = const Entitlement.pro();
    await tester.pumpAndSettle();
    await tap(tester, 'Render H.264');
    await finish(tester);
    expect(app.ads.exportInterstitialPreloaded, greaterThanOrEqualTo(1));
    expect(app.ads.exportInterstitialShown, 0);
  }, variant: mobile);

  testWidgets('repeated Export actions share one panel and show no ad', (
    tester,
  ) async {
    await open(tester, openExport: false);
    final context = tester.element(find.byType(EditorScreen));
    final first = ExportSheet.show(context);
    final second = ExportSheet.show(context);
    await tester.pumpAndSettle();
    expect(find.byType(ExportSheet), findsOneWidget);
    expect(app.ads.exportInterstitialShown, 0);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await Future.wait([first, second]);
  }, variant: mobile);

  testWidgets('a render finishing in the background of the editor shows it', (
    tester,
  ) async {
    app.encoder.frameTime = const Duration(milliseconds: 50);
    final container = await open(tester);
    await tap(tester, 'Render H.264');
    expect(container.read(exportControllerProvider).rendering, isTrue);
    await tap(tester, 'Keep working · renders in background');
    expect(find.byType(ExportSheet), findsNothing);
    expect(app.ads.exportInterstitialShown, 0);
    await finish(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      container.read(exportControllerProvider).run?.phase,
      ExportPhase.done,
    );
    expect(app.ads.exportInterstitialShown, 1);
  }, variant: mobile);

  testWidgets('a Free entitlement arriving while editing warms the ad', (
    tester,
  ) async {
    app.plan = FakeEntitlementRepository(const Entitlement.pro());
    await open(tester, openExport: false);
    expect(app.ads.exportInterstitialPreloaded, 0);
    app.plan.entitlement = const Entitlement.free();
    await tester.pumpAndSettle();
    expect(app.ads.exportInterstitialPreloaded, 1);
    await tap(tester, 'Export');
    expect(app.ads.exportInterstitialShown, 0);
    await tap(tester, 'Render H.264');
    await finish(tester);
    expect(app.ads.exportInterstitialShown, 1);
  }, variant: mobile);

  group('tablet', () {
    const tablet = Size(1194, 834);

    testWidgets('Export opens the page with no ad; a finished render shows one', (
      tester,
    ) async {
      await app.pump(tester, size: tablet);
      await tap(tester, 'The Long Way Down');
      expect(app.ads.exportInterstitialPreloaded, greaterThan(0));
      await tap(tester, 'Export');
      expect(app.ads.exportInterstitialShown, 0);
      expect(find.text('Render the roll.'), findsOneWidget);
      await tap(tester, 'Render');
      await finish(tester);
      expect(app.ads.exportInterstitialShown, 1);
    }, variant: mobile);

    testWidgets('Export… from the project menu opens straight on the page', (
      tester,
    ) async {
      await app.pump(tester, size: tablet);
      await tester.tap(find.byTooltip('Project actions').first);
      await tester.pumpAndSettle();
      await tap(tester, 'Export…');
      expect(app.ads.exportInterstitialShown, 0);
      expect(find.text('Render the roll.'), findsOneWidget);
    }, variant: mobile);
  });
}
