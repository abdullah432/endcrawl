import 'package:endcrawl/domain/models/entitlement.dart';
import 'package:endcrawl/domain/models/project_settings.dart';
import 'package:endcrawl/domain/models/render_summary.dart';
import 'package:endcrawl/features/export/models/export_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  late AppHarness app;

  setUp(() => app = AppHarness(projects: FakeProjectRepository(seed: [film()])));

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openExport(WidgetTester tester) async {
    await app.pump(tester);
    await tester.tap(find.text('The Long Way Down'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Export');
  }

  /// The simulated encode runs on a timer; let it finish.
  Future<void> runRender(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 110));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  RenderSummary? lastRender() => app.projects.projects.values.single.lastRender;

  group('6.1 settings', () {
    testWidgets('locked facts come first, then codecs with sizes and the resolution', (tester) async {
      await openExport(tester);

      expect(find.text('LOCKED FOR THIS RENDER'), findsOneWidget);
      expect(find.text('1920 × 1080'), findsOneWidget);
      expect(find.text('24 fps'), findsOneWidget);
      expect(find.text('4.00 px/f'), findsOneWidget);
      for (final c in Codec.values) {
        expect(find.text(c.label), findsOneWidget);
      }
      expect(find.text('1920 HD'), findsOneWidget);
      expect(find.text('Render H.264'), findsOneWidget);
      expect(find.textContaining(' MB'), findsWidgets);
    });

    testWidgets('picking a codec renames the render button', (tester) async {
      await openExport(tester);
      await tapText(tester, 'HEVC');
      expect(find.text('Render HEVC'), findsOneWidget);
    });

    testWidgets('a transparent background starts on an alpha codec', (tester) async {
      final base = film();
      app = AppHarness(projects: FakeProjectRepository(seed: [
        base.copyWith(settings: base.settings.copyWith(background: MonitorBackground.alpha)),
      ]));
      await openExport(tester);

      expect(find.text('Render ProRes 4444'), findsOneWidget);
      await tapText(tester, 'H.264');
      expect(find.text('H.264 has no alpha'), findsOneWidget);
    });
  });

  group('6.2 – 6.4 rendering', () {
    testWidgets('free renders show progress and the one ad, then land ready and recorded', (tester) async {
      await openExport(tester);
      await tapText(tester, 'Render H.264');

      expect(find.textContaining(RegExp(r'^frame \d')), findsOneWidget);
      expect(find.text('SPONSORED · WHILE YOU WAIT'), findsOneWidget);
      expect(find.text('Keep working · renders in background'), findsOneWidget);

      await runRender(tester);

      expect(find.textContaining('H.264 · 1920 × 1080 · 24 fps'), findsOneWidget);
      expect(find.text('Save to Files'), findsOneWidget);
      expect(find.text('SPONSORED · WHILE YOU WAIT'), findsNothing);
      expect(lastRender()?.outcome, RenderOutcome.rendered);
      expect(lastRender()?.codec, 'H.264');
    });

    testWidgets('Pro renders show no ad', (tester) async {
      app = AppHarness(
        projects: FakeProjectRepository(seed: [film()]),
        plan: FakeEntitlementRepository(const Entitlement.pro(period: BillingPeriod.yearly)),
      );
      await openExport(tester);
      await tapText(tester, 'Render H.264');

      expect(find.textContaining(RegExp(r'^frame \d')), findsOneWidget);
      expect(find.text('SPONSORED · WHILE YOU WAIT'), findsNothing);
      await runRender(tester);
    });

    testWidgets('a failure names the cause and resumes from where it stopped', (tester) async {
      await openExport(tester);
      await tapText(tester, '4K UHD');
      await tapText(tester, 'Render H.264');
      await runRender(tester);

      expect(find.text('STOPPED AT 62%'), findsOneWidget);
      expect(find.textContaining('the first 62% is cached'), findsOneWidget);
      expect(lastRender()?.outcome, RenderOutcome.failed);

      await tapText(tester, 'Resume');
      expect(find.textContaining(RegExp(r'^frame \d')), findsOneWidget);
      await runRender(tester);

      expect(find.textContaining('3840 × 2160'), findsOneWidget);
      expect(lastRender()?.outcome, RenderOutcome.rendered);
    });

    testWidgets('lower resolution carries on at 1920', (tester) async {
      await openExport(tester);
      await tapText(tester, '4K UHD');
      await tapText(tester, 'Render H.264');
      await runRender(tester);

      await tapText(tester, 'Lower resolution');
      await runRender(tester);

      expect(find.textContaining('H.264 · 1920 × 1080'), findsOneWidget);
    });

    testWidgets('a render keeps going in the background and the library shows it', (tester) async {
      await openExport(tester);
      await tester.tap(find.text('Render H.264'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Keep working · renders in background'));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byTooltip('Back'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('RENDERING '), findsOneWidget);

      await runRender(tester);
      expect(find.textContaining('RENDERED'), findsOneWidget);
    });
  });

  group('estimates', () {
    test('sizes and times follow the design at 2:41 of 1080p', () {
      expect(formatBytes(estimateBytes(Codec.h264, 1920, 1080, 161)), '242 MB');
      expect(formatBytes(estimateBytes(Codec.prores4444, 1920, 1080, 161)), '4.4 GB');
      expect(formatAbout(estimateRenderSeconds(1920, 1080, 161)), 'about 3 min');
    });

    test('resolution keeps the canvas aspect, in even pixels', () {
      expect(ExportResolution.hd.sizeFor(2048, 858), (1920, 804));
      expect(ExportResolution.uhd.sizeFor(1920, 1080), (3840, 2160));
      expect(ExportResolution.nearest(1998), ExportResolution.hd);
    });
  });
}
