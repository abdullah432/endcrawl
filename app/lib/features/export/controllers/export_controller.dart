import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../domain/models/project_settings.dart';
import '../../../domain/models/render_summary.dart';
import '../../library/controllers/library_controller.dart';
import '../../project/controllers/project_controller.dart';
import '../models/export_models.dart';

class ExportState {
  /// The codec picked on 6.1; until one is, the background decides —
  /// transparent means an alpha codec.
  final Codec? codec;
  final ExportResolution? resolution;
  final ExportRun? run;

  const ExportState({this.codec, this.resolution, this.run});

  Codec codecFor(ProjectSettings s) => codec ?? (s.background == MonitorBackground.alpha ? Codec.prores4444 : Codec.h264);
  ExportResolution resolutionFor(int canvasWidth) => resolution ?? ExportResolution.nearest(canvasWidth);

  bool get rendering => run?.phase == ExportPhase.running;
}

/// Renders the open project (6.1–6.4).
///
/// The render is simulated — this build has no encoder — but everything
/// around it is real: the locked settings, size and time estimates, the
/// progress the library shows, and the outcome written to the project as
/// its last render. A 4K render stops once at 62% for lack of space, the
/// case 6.3 designs for; Resume or a lower resolution carries on from the
/// cached frames.
class ExportController extends Notifier<ExportState> {
  static const _tick = Duration(milliseconds: 110);
  static const _step = 0.025;
  static const _spaceFailureAt = 0.62;

  Timer? _timer;
  bool _spaceFailed = false;

  @override
  ExportState build() {
    ref.onDispose(() => _timer?.cancel());
    return const ExportState();
  }

  void setCodec(Codec c) => state = ExportState(codec: c, resolution: state.resolution, run: state.run);
  void setResolution(ExportResolution r) => state = ExportState(codec: state.codec, resolution: r, run: state.run);

  /// Starts rendering the open project with the chosen settings.
  void start() {
    final project = ref.read(projectControllerProvider);
    final e = project.engine;
    final (w, h) = state.resolutionFor(project.formatW).sizeFor(project.formatW, project.formatH);
    _spaceFailed = false;
    _run(ExportRun(
      projectId: project.project.id,
      projectTitle: project.name,
      codec: state.codecFor(project.settings),
      width: w,
      height: h,
      fps: e.fps,
      totalFrames: e.totalFrames.round(),
    ));
  }

  /// Carries on after a failure from where it stopped.
  void resume() {
    final run = state.run;
    if (run == null || run.phase != ExportPhase.failed) return;
    _run(run.copyWith(phase: ExportPhase.running));
  }

  /// Drops to 1920 and carries on — the smaller file fits.
  void resumeAtLowerResolution() {
    final run = state.run;
    if (run == null || run.phase != ExportPhase.failed) return;
    final project = ref.read(projectControllerProvider);
    final (w, h) = ExportResolution.hd.sizeFor(project.formatW, project.formatH);
    state = ExportState(codec: state.codec, resolution: ExportResolution.hd, run: run);
    _run(run.copyWith(phase: ExportPhase.running, width: w, height: h));
  }

  /// Clears a finished or failed render, back to 6.1.
  void dismiss() {
    if (state.rendering) return;
    state = ExportState(codec: state.codec, resolution: state.resolution);
  }

  void _run(ExportRun run) {
    _timer?.cancel();
    state = ExportState(codec: state.codec, resolution: state.resolution, run: run);
    _timer = Timer.periodic(_tick, (_) => _advance());
  }

  void _advance() {
    final run = state.run;
    if (run == null || run.phase != ExportPhase.running) {
      _timer?.cancel();
      return;
    }
    final next = (run.progress + _step).clamp(0.0, 1.0);
    if (!_spaceFailed && run.width >= ExportResolution.uhd.width && next >= _spaceFailureAt) {
      _spaceFailed = true;
      _finish(run.copyWith(
        progress: _spaceFailureAt,
        phase: ExportPhase.failed,
        neededBytes: run.bytes * (1 - _spaceFailureAt),
      ));
      return;
    }
    if (next >= 1) {
      _finish(run.copyWith(progress: 1, phase: ExportPhase.done));
      return;
    }
    state = ExportState(codec: state.codec, resolution: state.resolution, run: run.copyWith(progress: next));
  }

  void _finish(ExportRun run) {
    _timer?.cancel();
    state = ExportState(codec: state.codec, resolution: state.resolution, run: run);
    _record(run);
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

final exportControllerProvider = NotifierProvider<ExportController, ExportState>(ExportController.new);

/// How far the render of [projectId] has got, while one is running — the
/// library card's "Rendering 38%".
final renderProgressProvider = Provider.family<double?, String>((ref, projectId) {
  final run = ref.watch(exportControllerProvider.select((s) => s.run));
  return run != null && run.projectId == projectId && run.phase == ExportPhase.running ? run.progress : null;
});
