import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/export/controllers/export_controller.dart';
import 'package:lastreel/features/export/data/video_encoder.dart';
import 'package:lastreel/features/export/models/export_models.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  late AppHarness app;
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  setUp(
    () => app = AppHarness(projects: FakeProjectRepository(seed: [film()])),
  );

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> open(WidgetTester tester) async {
    await app.pump(tester);
    await tap(tester, 'The Long Way Down');
    await tap(tester, 'Export');
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
    'preloads during export, shows once on success, keeps destinations usable',
    (tester) async {
      await open(tester);
      await tap(tester, 'Render H.264');
      expect(app.ads.exportInterstitialPreloaded, 1);
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
    variant: android,
  );

  testWidgets(
    'failed exports show no interstitial; successful retry shows one',
    (tester) async {
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
    },
    variant: android,
  );

  testWidgets('cancelled exports show no interstitial', (tester) async {
    final container = await open(tester);
    await tap(tester, 'Render H.264');
    container.read(exportControllerProvider.notifier).cancel();
    await finish(tester);
    expect(app.ads.exportInterstitialShown, 0);
  }, variant: android);

  testWidgets(
    'ad errors cannot change successful output into a failed render',
    (tester) async {
      app.ads.exportInterstitialFailure = StateError('SDK unavailable');
      final container = await open(tester);
      await tap(tester, 'Render H.264');
      await finish(tester);
      expect(
        container.read(exportControllerProvider).run?.phase,
        ExportPhase.done,
      );
      expect(find.text('Save to Files'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: android,
  );

  testWidgets('Pro exports never preload or show the interstitial', (
    tester,
  ) async {
    app.plan = FakeEntitlementRepository(const Entitlement.pro());
    await open(tester);
    await tap(tester, 'Render H.264');
    await finish(tester);
    expect(app.ads.exportInterstitialPreloaded, 0);
    expect(app.ads.exportInterstitialShown, 0);
  }, variant: android);

  testWidgets('upgrading during a render suppresses the completion ad', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, 'Render H.264');
    app.plan.entitlement = const Entitlement.pro();
    await finish(tester);
    expect(app.ads.exportInterstitialPreloaded, 1);
    expect(app.ads.exportInterstitialShown, 0);
  }, variant: android);

  testWidgets(
    'iOS does not use the Android interstitial placement',
    (tester) async {
      await open(tester);
      await tap(tester, 'Render H.264');
      await finish(tester);
      expect(app.ads.exportInterstitialPreloaded, 0);
      expect(app.ads.exportInterstitialShown, 0);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
