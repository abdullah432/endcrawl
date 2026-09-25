import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../domain/models/project_settings.dart';
import '../../../domain/models/render_summary.dart';
import '../../library/controllers/library_controller.dart';
import '../../project/controllers/project_controller.dart';
import '../data/export_destinations.dart';
import '../data/native_video_encoder.dart';
import '../data/png_sequence_encoder.dart';
import '../data/video_encoder.dart';
import '../models/export_models.dart';
import '../render/frame_renderer.dart';
import '../render/frame_source.dart';

final videoEncoderProvider = Provider<VideoEncoder>(
  (ref) => const RoutingVideoEncoder(video: NativeVideoEncoder(), images: PngSequenceEncoder()),
);

/// What this device can encode — 6.1 offers only these.
final encoderCapabilitiesProvider = FutureProvider<EncoderCapabilities>(
  (ref) => ref.watch(videoEncoderProvider).capabilities(),
);

final frameSourceFactoryProvider = Provider<FrameSourceFactory>((ref) => FrameRenderer.open);

final exportDestinationsProvider = Provider<ExportDestinations>((ref) => const PlatformExportDestinations());

/// Where renders are written: the cache, which the OS may clear, since a
/// render is handed on to Photos, Files or another app straight away.
final exportDirectoryProvider = Provider<Future<String> Function()>((ref) {
  return () async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'renders'));
    await dir.create(recursive: true);
    return dir.path;
  };
});

class ExportState {
  /// The codec picked on 6.1; until one is, the background decides —
  /// transparent means an alpha codec.
  final Codec? codec;
  final ExportResolution? resolution;
  final ExportRun? run;

  /// A Pro render earned by a rewarded ad, not yet spent.
  final ProRenderPass? pass;

  const ExportState({this.codec, this.resolution, this.run, this.pass});

  /// The codec a render would use: the one picked if this device has it,
  /// else the best fit for the background.
  Codec codecFor(ProjectSettings s, EncoderCapabilities? caps) {
    final available = caps?.codecs.toList() ?? Codec.values;
    if (codec case final c? when available.contains(c)) return c;
    if (s.background == MonitorBackground.alpha) {
      for (final c in Codec.alphaCodecs) {
        if (available.contains(c)) return c;
      }
    }
    return available.contains(Codec.h264) ? Codec.h264 : available.first;
  }

  /// The sizes [codec] can be made at on this device.
  List<ExportResolution> resolutionsFor(Codec codec, EncoderCapabilities? caps) {
    final options = caps?.resolutionsFor(codec).toList() ?? ExportResolution.values;
    return options.isEmpty ? const [ExportResolution.small] : options;
  }

  /// The size picked, or the one nearest the canvas — among the free sizes
  /// on the free plan, so a 4K canvas doesn't open on a Pro option.
  ExportResolution resolutionFor(int canvasW, int canvasH, Codec codec, EncoderCapabilities? caps, {bool isPro = true}) {
    final options = resolutionsFor(codec, caps);
    if (resolution case final r? when options.contains(r)) return r;
    final free = options.where((r) => !r.isPro);
    return ExportResolution.nearest(canvasW, canvasH, isPro || free.isEmpty ? options : free);
  }

  /// Whether these settings can render now (6.1).
  ExportAccess accessFor(String projectId, Codec codec, ExportResolution resolution, {required bool isPro}) {
    if (isPro || (!codec.isPro && !resolution.isPro)) return ExportAccess.included;
    return pass?.covers(projectId, codec, resolution) ?? false ? ExportAccess.unlocked : ExportAccess.locked;
  }

  bool get rendering => run?.phase == ExportPhase.running;

  ExportState copyWith({Codec? codec, ExportResolution? resolution, ProRenderPass? pass, bool clearPass = false}) =>
      ExportState(
        codec: codec ?? this.codec,
        resolution: resolution ?? this.resolution,
        run: run,
        pass: clearPass ? null : pass ?? this.pass,
      );

  ExportState withRun(ExportRun? run) => ExportState(codec: codec, resolution: resolution, run: run, pass: pass);
}

/// Renders the open project (6.1–6.4) for real: each frame is drawn
/// offscreen by the same widget the monitor plays, handed to the platform
/// encoder, and the file's real size is shown when it lands.
///
/// One render at a time. It carries on while the sheet is closed, pauses
/// while the app is in the background (the GPU isn't available there), and
/// writes its outcome to the project so the library's pill is true.
class ExportController extends Notifier<ExportState> {
  _Job? _job;
  AppLifecycleListener? _lifecycle;

  @override
  ExportState build() {
    ref.onDispose(() {
      _job?.cancel();
      _lifecycle?.dispose();
    });
    return const ExportState();
  }

  void setCodec(Codec c) => state = state.copyWith(codec: c);
  void setResolution(ExportResolution r) => state = state.copyWith(resolution: r);

  bool get _isPro => ref.read(entitlementProvider).value?.isPro ?? false;

  /// The settings a render would use now: codec, size, and whether they
  /// can start.
  (Codec, ExportResolution, ExportAccess) selection() {
    final project = ref.read(projectControllerProvider);
    final caps = ref.read(encoderCapabilitiesProvider).value;
    final codec = state.codecFor(project.settings, caps);
    final resolution = state.resolutionFor(project.formatW, project.formatH, codec, caps, isPro: _isPro);
    return (codec, resolution, state.accessFor(project.project.id, codec, resolution, isPro: _isPro));
  }

  /// Grants one Pro render with the current settings — the reward for
  /// watching a rewarded ad to the end (6.1a).
  void grantPass() {
    final project = ref.read(projectControllerProvider);
    final (codec, resolution, _) = selection();
    state = state.copyWith(pass: ProRenderPass(projectId: project.project.id, codec: codec, resolution: resolution));
  }

  /// Starts rendering the open project with the chosen settings. Refuses
  /// Pro settings on the free plan without a pass — the gate is here, not
  /// just a hidden button.
  bool start() {
    if (state.rendering) return false;
    final (codec, resolution, access) = selection();
    if (access == ExportAccess.locked) return false;
    final project = ref.read(projectControllerProvider);
    final (w, h) = resolution.sizeFor(project.formatW, project.formatH);
    final run = ExportRun(
      projectId: project.project.id,
      projectTitle: project.name,
      codec: codec,
      width: w,
      height: h,
      fps: project.engine.fps,
      totalFrames: project.engine.totalFrames.round(),
      onPass: access == ExportAccess.unlocked,
    );
    final job = _job = _Job();
    state = state.withRun(run);
    _watchLifecycle();
    unawaited(_render(job, project, run));
    return true;
  }

  /// Starts a failed render again, from the top. A render unlocked by an
  /// ad still has its pass, so the retry is free.
  void retry() {
    if (state.run?.phase != ExportPhase.failed) return;
    start();
  }

  /// Starts a failed render again at 1920 — a quarter of 4K's size, and
  /// still covered by the pass.
  void retryAtLowerResolution() {
    if (state.run?.phase != ExportPhase.failed) return;
    setResolution(ExportResolution.hd);
    start();
  }

  /// Stops the render and throws the partial file away.
  void cancel() {
    if (!state.rendering) return;
    _job?.cancel();
    _job = null;
    _stopWatchingLifecycle();
    state = state.withRun(null);
  }

  /// Clears a finished or failed render, back to 6.1.
  void dismiss() {
    if (state.rendering) return;
    state = state.withRun(null);
  }

  Future<void> _render(_Job job, ProjectState project, ExportRun run) async {
    FrameSource? source;
    EncodeSession? session;
    var written = 0;
    try {
      final caps = await ref.read(encoderCapabilitiesProvider.future);
      if (caps.freeBytes case final free? when run.bytes * 1.1 > free) {
        throw const EncoderException.outOfSpace();
      }

      source = await ref.read(frameSourceFactoryProvider)(
        settings: project.settings,
        blocks: project.activeBlocks,
        geometry: project.geometry,
        outputWidth: run.width,
        outputHeight: run.height,
      );
      if (job.cancelled) return;
      run = run.copyWith(totalFrames: source.frameCount);
      _update(job, run);

      final dir = await ref.read(exportDirectoryProvider)();
      final path = p.join(dir, exportFileName(run.projectTitle, run.codec));

      session = await ref.read(videoEncoderProvider).start(EncodeSpec(
        codec: run.codec,
        width: run.width,
        height: run.height,
        fps: run.fps,
        bitsPerSecond: bitsPerSecond(run.codec, run.width, run.height),
        outputPath: path,
      ));

      final pace = Stopwatch()..start();
      var shown = Duration.zero;
      for (var i = 0; i < source.frameCount; i++) {
        if (job.paused) {
          pace.stop();
          await job.resumed;
          pace.start();
        }
        if (job.cancelled) {
          await session.cancel();
          return;
        }

        final image = await source.render(i);
        try {
          // Rendering can yield across a lifecycle change. Keep this frame
          // until the app is active before handing it to the native encoder.
          if (job.paused) {
            pace.stop();
            await job.resumed;
            pace.start();
          }
          if (job.cancelled) {
            await session.cancel();
            return;
          }
          await session.append(image, i);
        } finally {
          image.dispose();
        }

        written = i + 1;
        if (pace.elapsed - shown >= const Duration(milliseconds: 100) || written == source.frameCount) {
          shown = pace.elapsed;
          // The pace settles after a few frames; until then keep the estimate.
          final left = written < 8 ? null : pace.elapsed.inMicroseconds / written * (source.frameCount - written) / 1e6;
          _update(job, run = run.copyWith(frame: written, measuredSecondsLeft: left));
        }
      }
      if (job.cancelled) {
        await session.cancel();
        return;
      }

      final out = await session.finish();
      session = null;
      _finish(job, run.copyWith(phase: ExportPhase.done, frame: run.totalFrames, outputPath: out.path, fileBytes: out.bytes));
    } on EncoderException catch (e) {
      await session?.cancel();
      _finish(job, run.copyWith(
        phase: ExportPhase.failed,
        frame: written,
        failure: e.kind,
        failureMessage: e.message,
        neededBytes: e.kind == EncoderFailureKind.outOfSpace ? run.bytes : null,
      ));
    } catch (e, s) {
      await session?.cancel();
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s, library: 'export'));
      _finish(job, run.copyWith(
        phase: ExportPhase.failed,
        frame: written,
        failure: EncoderFailureKind.failed,
        failureMessage: 'The render stopped unexpectedly.',
      ));
    } finally {
      source?.dispose();
      if (identical(_job, job) && !state.rendering) _stopWatchingLifecycle();
    }
  }

  void _update(_Job job, ExportRun run) {
    if (identical(_job, job) && !job.cancelled) state = state.withRun(run);
  }

  void _finish(_Job job, ExportRun run) {
    if (!identical(_job, job) || job.cancelled) return;
    _job = null;
    // A pass is spent by the render it unlocked succeeding, not by trying.
    state = (run.onPass && run.phase == ExportPhase.done ? state.copyWith(clearPass: true) : state).withRun(run);
    _stopWatchingLifecycle();
    unawaited(_record(run));
  }

  void _watchLifecycle() {
    _lifecycle ??= AppLifecycleListener(
      onInactive: () => _job?.pause(),
      onResume: () => _job?.resume(),
    );
  }

  void _stopWatchingLifecycle() {
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  /// Writes the outcome to the project, so the library's pill is true on
  /// every device. Through the open document when it is still open, else
  /// straight to the store.
  Future<void> _record(ExportRun run) async {
    final summary = RenderSummary(
      outcome: run.phase == ExportPhase.done ? RenderOutcome.rendered : RenderOutcome.failed,
      codec: run.codec.label,
      width: run.width,
      height: run.height,
      at: ref.read(clockProvider)(),
    );
    final open = ref.read(projectControllerProvider).project;
    if (open.id == run.projectId) {
      await ref.read(projectControllerProvider.notifier).recordRender(summary);
    } else {
      final repo = ref.read(projectRepositoryProvider);
      if (await repo.load(run.projectId) case Ok(:final value)) {
        await repo.save(value.copyWith(lastRender: summary));
      }
    }
    ref.invalidate(projectSummariesProvider);
  }
}

/// One render's pause and cancel switches.
class _Job {
  bool cancelled = false;
  Completer<void>? _resume;

  bool get paused => _resume != null;
  Future<void> get resumed => _resume?.future ?? Future.value();

  void pause() => _resume ??= Completer<void>();

  void resume() {
    _resume?.complete();
    _resume = null;
  }

  void cancel() {
    cancelled = true;
    resume();
  }
}

final exportControllerProvider = NotifierProvider<ExportController, ExportState>(ExportController.new);

/// How far the render of [projectId] has got, while one is running — the
/// library card's "Rendering 38%".
final renderProgressProvider = Provider.family<double?, String>((ref, projectId) {
  final run = ref.watch(exportControllerProvider.select((s) => s.run));
  return run != null && run.projectId == projectId && run.phase == ExportPhase.running ? run.progress : null;
});
