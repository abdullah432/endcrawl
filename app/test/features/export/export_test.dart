import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/domain/models/project_settings.dart';
import 'package:lastreel/domain/models/render_summary.dart';
import 'package:lastreel/features/export/data/video_encoder.dart';
import 'package:lastreel/features/export/models/export_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_export.dart';
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

  /// Each fake frame takes 20 ms; let the render run its course.
  Future<void> runRender(WidgetTester tester) async {
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
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
      expect(find.text('≈ 242 MB'), findsNothing); // runtime differs from the design's 2:41
      expect(find.textContaining(RegExp(r'^≈ \d+ (MB|GB|KB)$')), findsNWidgets(Codec.values.length));
    });

    testWidgets('a fractional speed is flagged, with a one-tap whole-pixel fix', (tester) async {
      app = AppHarness(projects: FakeProjectRepository(seed: [film(mode: TimingMode.duration, durationFrames: 24 * 47 + 5)]));
      await openExport(tester);

      expect(find.textContaining(RegExp(r'^Moves \d+\.\d+ px a frame$')), findsOneWidget);
      final fix = tester.widget<Text>(find.textContaining(RegExp(r'^Use \d+:\d\d · \d+ px/f$'))).data!;
      await tapText(tester, fix);
      expect(find.textContaining('px a frame'), findsNothing);
    });

    testWidgets('only what this device can encode is offered', (tester) async {
      app = AppHarness(projects: FakeProjectRepository(seed: [film()]), encoder: FakeVideoEncoder(caps: FakeVideoEncoder.android));
      await openExport(tester);

      expect(find.text('ProRes 422 HQ'), findsNothing);
      expect(find.text('ProRes 4444'), findsNothing);
      expect(find.text('4K UHD'), findsOneWidget);

      await tapText(tester, 'HEVC');
      expect(find.text('4K UHD'), findsNothing, reason: 'this HEVC encoder stops at 1920');
    });

    testWidgets('a transparent background falls back to PNG where ProRes can’t be made', (tester) async {
      final base = film();
      app = AppHarness(
        projects: FakeProjectRepository(seed: [base.copyWith(settings: base.settings.copyWith(background: MonitorBackground.alpha))]),
        encoder: FakeVideoEncoder(caps: FakeVideoEncoder.android),
      );
      await openExport(tester);
      expect(find.text('Render PNG sequence'), findsOneWidget);
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
    testWidgets('free renders show progress and the one ad, then land ready with the real size', (tester) async {
      await openExport(tester);
      await tapText(tester, 'Render H.264');

      expect(find.textContaining(RegExp(r'^frame \d+ / 48$')), findsOneWidget);
      expect(find.text('SPONSORED · WHILE YOU WAIT'), findsOneWidget);
      expect(find.text('Keep working · renders in background'), findsOneWidget);

      await runRender(tester);

      final spec = app.encoder.started.single;
      expect((spec.codec, spec.width, spec.height, spec.fps), (Codec.h264, 1920, 1080, 24.0));
      expect(spec.bitsPerSecond, 12000000);
      expect(spec.outputPath, '/renders/The Long Way Down.mp4');
      expect(app.encoder.appended, 48);
      expect(app.frames.opened.single, (1920, 1080));

      // 48 frames × 1000 bytes from the fake encoder: the file's own size.
      expect(find.textContaining('H.264 · 1920 × 1080 · 24 fps · 48 KB'), findsOneWidget);
      expect(find.text('SPONSORED · WHILE YOU WAIT'), findsNothing);
      expect(lastRender()?.outcome, RenderOutcome.rendered);
      expect(lastRender()?.codec, 'H.264');
    });

    testWidgets('the finished file goes to Photos and the share sheet', (tester) async {
      await openExport(tester);
      await tapText(tester, 'Render H.264');
      await runRender(tester);

      await tapText(tester, 'Save to Photos');
      expect(app.destinations.savedToPhotos, ['/renders/The Long Way Down.mp4']);
      expect(find.text('Saved to Photos'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // the toast leaves
      await tester.pumpAndSettle();

      await tapText(tester, 'Share sheet');
      await tapText(tester, 'Save to Files');
      expect(app.destinations.shared, hasLength(2));
    });

    testWidgets('an image sequence isn’t offered to Photos', (tester) async {
      await openExport(tester);
      await tapText(tester, 'PNG sequence');
      await tapText(tester, 'Render PNG sequence');
      await runRender(tester);

      expect(app.encoder.started.single.outputPath, endsWith('.zip'));
      expect(find.text('Save to Photos'), findsNothing);
      expect(find.text('Save to Files'), findsOneWidget);
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

    testWidgets('out of space names the cause and the size, and tries again', (tester) async {
      app = AppHarness(
        projects: FakeProjectRepository(seed: [film()]),
        encoder: FakeVideoEncoder(failWith: const EncoderException.outOfSpace(), failAtFrame: 30),
      );
      await openExport(tester);
      await tapText(tester, '4K UHD');
      await tapText(tester, 'Render H.264');
      await runRender(tester);

      expect(find.text('STOPPED AT 62%'), findsOneWidget);
      expect(find.textContaining('Not enough '), findsOneWidget);
      expect(find.textContaining('Free up space or drop to 1920'), findsOneWidget);
      expect(app.encoder.cancelled, 1, reason: 'the partial file is removed');
      expect(lastRender()?.outcome, RenderOutcome.failed);

      await tapText(tester, 'Try again');
      expect(find.textContaining(RegExp(r'^frame \d')), findsOneWidget);
      await runRender(tester);

      expect(find.textContaining('3840 × 2160'), findsOneWidget);
      expect(lastRender()?.outcome, RenderOutcome.rendered);
    });

    testWidgets('lower resolution starts again at 1920', (tester) async {
      app = AppHarness(
        projects: FakeProjectRepository(seed: [film()]),
        encoder: FakeVideoEncoder(failWith: const EncoderException.outOfSpace(), failAtFrame: 10),
      );
      await openExport(tester);
      await tapText(tester, '4K UHD');
      await tapText(tester, 'Render H.264');
      await runRender(tester);

      await tapText(tester, 'Lower resolution');
      await runRender(tester);

      expect(app.frames.opened, [(3840, 2160), (1920, 1080)]);
      expect(find.textContaining('H.264 · 1920 × 1080'), findsOneWidget);
    });

    testWidgets('a device that reports too little space stops before the first frame', (tester) async {
      app = AppHarness(
        projects: FakeProjectRepository(seed: [film()]),
        encoder: FakeVideoEncoder(caps: EncoderCapabilities(FakeVideoEncoder.everything.maxEdge, freeBytes: 1000)),
      );
      await openExport(tester);
      await tapText(tester, 'Render H.264');
      await runRender(tester);

      expect(find.text('STOPPED AT 0%'), findsOneWidget);
      expect(app.encoder.started, isEmpty);
    });

    testWidgets('any other encoder failure says what the encoder said', (tester) async {
      app = AppHarness(
        projects: FakeProjectRepository(seed: [film()]),
        encoder: FakeVideoEncoder(failWith: const EncoderException(EncoderFailureKind.failed, 'The encoder ran out of memory.')),
      );
      await openExport(tester);
      await tapText(tester, 'Render H.264');
      await runRender(tester);

      expect(find.textContaining('stopped.'), findsOneWidget);
      expect(find.textContaining('The encoder ran out of memory.'), findsOneWidget);
      expect(find.text('Lower resolution'), findsNothing);
    });

    testWidgets('cancel stops the render and removes the partial file', (tester) async {
      await openExport(tester);
      await tapText(tester, 'Render H.264');
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Cancel render'));
      await runRender(tester);

      expect(app.encoder.cancelled, 1);
      expect(app.encoder.appended, lessThan(48));
      expect(find.text('Render H.264'), findsOneWidget);
      expect(lastRender(), isNull);
    });

    testWidgets('the render pauses while the app is in the background', (tester) async {
      await openExport(tester);
      await tapText(tester, 'Render H.264');
      await tester.pump(const Duration(milliseconds: 200));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 100));
      final before = app.encoder.appended;
      await tester.pump(const Duration(seconds: 2));
      expect(app.encoder.appended, before);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 2));
      expect(app.encoder.appended, before);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await runRender(tester);
      expect(app.encoder.appended, 48);
      expect(find.text('Save to Files'), findsOneWidget);
    });

    testWidgets('a render keeps going with the sheet closed and the library shows it', (tester) async {
      app = AppHarness(projects: FakeProjectRepository(seed: [film()]), frames: FakeFrames(frames: 200));
      await openExport(tester);
      await tester.tap(find.text('Render H.264'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Keep working · renders in background'));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byTooltip('Back'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('RENDERING '), findsOneWidget);

      for (var i = 0; i < 4; i++) {
        await runRender(tester);
      }
      expect(find.textContaining('RENDERED'), findsOneWidget);
    });
  });

  group('estimates', () {
    test('sizes and times follow the design at 2:41 of 1080p', () {
      expect(formatBytes(estimateBytes(Codec.h264, 1920, 1080, 161)), '242 MB');
      expect(formatBytes(estimateBytes(Codec.prores4444, 1920, 1080, 161)), '4.4 GB');
      expect(formatAbout(estimateRenderSeconds(1920, 1080, 161)), 'about 3 min');
    });

    test('H.264 and HEVC are encoded at the rate the estimate assumes', () {
      expect(bitsPerSecond(Codec.h264, 1920, 1080), 12000000);
      expect(bitsPerSecond(Codec.hevc, 3840, 2160), 36000000);
    });

    test('resolution is the long edge, keeps the canvas aspect, in even pixels', () {
      expect(ExportResolution.hd.sizeFor(2048, 858), (1920, 804));
      expect(ExportResolution.uhd.sizeFor(1920, 1080), (3840, 2160));
      expect(ExportResolution.hd.sizeFor(1080, 1920), (1080, 1920));
      expect(ExportResolution.nearest(1998, 1080), ExportResolution.hd);
      expect(ExportResolution.nearest(1080, 1920), ExportResolution.hd);
    });

    test('NTSC rates stay exact fractions', () {
      expect(frameRateFraction(24), (24, 1));
      expect(frameRateFraction(23.976), (24000, 1001));
      expect(frameRateFraction(29.97), (30000, 1001));
      expect(frameRateFraction(59.94), (60000, 1001));
    });

    test('file names keep the title, minus what filesystems refuse', () {
      expect(exportFileName('The Long Way Down', Codec.hevc), 'The Long Way Down.mp4');
      expect(exportFileName('A/B: "C"?', Codec.prores422), 'AB C.mov');
      expect(exportFileName('  ', Codec.png), 'LastReel render.zip');
    });
  });
}
