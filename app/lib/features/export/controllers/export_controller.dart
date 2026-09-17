import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/export_models.dart';

class ExportState {
  final Codec codec;
  final ExportResolution resolution;
  final ExportRun? run;

  const ExportState({this.codec = Codec.prores, this.resolution = ExportResolution.source, this.run});

  ExportState copyWith({Codec? codec, ExportResolution? resolution, ExportRun? run, bool clearRun = false}) {
    return ExportState(
      codec: codec ?? this.codec,
      resolution: resolution ?? this.resolution,
      run: clearRun ? null : (run ?? this.run),
    );
  }
}

/// The export sheet's simulated render — this build is UI/UX fidelity
/// only (per product decision), so there is no real encoder behind it.
/// The progress ramp and the "ran out of space at 62%" failure case are
/// both ported verbatim from the prototype's `startExport()` so the
/// screen states (idle/running/failed/done) behave exactly like the design.
class ExportController extends Notifier<ExportState> {
  Timer? _timer;

  @override
  ExportState build() {
    ref.onDispose(() => _timer?.cancel());
    return const ExportState();
  }

  void setCodec(Codec c) => state = state.copyWith(codec: c);
  void setResolution(ExportResolution r) => state = state.copyWith(resolution: r);

  void editSettings() {
    _timer?.cancel();
    state = state.copyWith(clearRun: true);
  }

  void start({required int sourceWidth}) {
    _timer?.cancel();
    state = state.copyWith(run: const ExportRun(pct: 0, phase: ExportPhase.running));
    _timer = Timer.periodic(const Duration(milliseconds: 110), (t) {
      final run = state.run;
      if (run == null || run.phase != ExportPhase.running) {
        t.cancel();
        return;
      }
      final pct = run.pct + 3.5;
      if (state.resolution == ExportResolution.source && pct >= 62 && sourceWidth > 2000) {
        t.cancel();
        state = state.copyWith(run: const ExportRun(pct: 62, phase: ExportPhase.failed));
        return;
      }
      if (pct >= 100) {
        t.cancel();
        state = state.copyWith(run: const ExportRun(pct: 100, phase: ExportPhase.done));
        return;
      }
      state = state.copyWith(run: ExportRun(pct: pct, phase: ExportPhase.running));
    });
  }

  void close() {
    state = state.copyWith(clearRun: true);
  }
}

final exportControllerProvider = NotifierProvider<ExportController, ExportState>(ExportController.new);
