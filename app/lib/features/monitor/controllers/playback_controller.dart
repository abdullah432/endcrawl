import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/engine/roll_engine.dart';
import '../../../domain/models/credit_block.dart';
import '../../project/controllers/project_controller.dart';

class PlaybackState {
  final double frame;
  final bool playing;
  const PlaybackState({this.frame = 0, this.playing = false});

  PlaybackState copyWith({double? frame, bool? playing}) =>
      PlaybackState(frame: frame ?? this.frame, playing: playing ?? this.playing);
}

/// Drives the monitor's frame position — this is the prototype's
/// `requestAnimationFrame` loop (`step()`/`play()`/`stop()`), reimplemented
/// with a periodic timer at real elapsed time so the roll's speed always
/// matches the stated duration regardless of the ~60Hz tick rate.
class PlaybackController extends Notifier<PlaybackState> {
  Timer? _timer;
  DateTime? _last;

  @override
  PlaybackState build() {
    ref.onDispose(() => _timer?.cancel());
    return const PlaybackState();
  }

  void play() {
    if (_timer != null) return;
    _last = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 16), _tick);
    state = state.copyWith(playing: true);
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    if (state.playing) state = state.copyWith(playing: false);
  }

  void togglePlay() => state.playing ? pause() : play();

  void _tick(Timer t) {
    final now = DateTime.now();
    final dt = (now.difference(_last!).inMicroseconds / 1e6).clamp(0, 0.25);
    _last = now;
    final e = ref.read(projectControllerProvider).engine;
    var next = state.frame + dt * e.fps;
    if (next >= e.totalFrames) next = 0;
    state = state.copyWith(frame: next);
  }

  void toHead() {
    pause();
    state = state.copyWith(frame: 0);
  }

  void toTail() {
    pause();
    final e = ref.read(projectControllerProvider).engine;
    state = state.copyWith(frame: (e.totalFrames - 1).clamp(0, double.infinity));
  }

  void stepBack() {
    pause();
    state = state.copyWith(frame: (state.frame - 1).clamp(0, double.infinity));
  }

  void stepForward() {
    pause();
    final e = ref.read(projectControllerProvider).engine;
    state = state.copyWith(frame: (state.frame + 1).clamp(0, (e.totalFrames - 1).clamp(0, double.infinity)));
  }

  void scrubToFraction(double t) {
    pause();
    final e = ref.read(projectControllerProvider).engine;
    state = state.copyWith(frame: t.clamp(0, 1) * e.totalFrames);
  }

  /// Jumps to where block [id] enters the frame — for a hold card, to the
  /// card itself.
  void seekToBlock(String id) {
    final project = ref.read(projectControllerProvider);
    final y = project.measurements.blockY[id];
    if (y == null) return;
    pause();
    final hold = project.activeBlocks.any((b) => b.id == id && b is HoldBlock);
    state = state.copyWith(frame: frameForY(project.engine, hold ? y + project.geometry.h : y));
  }

  /// Resets to the head — used when a template loads or the roll content
  /// changes shape enough that the old frame position no longer means
  /// anything (mirrors `this.frame=0` calls around `seed()`/`goEditor()`).
  void resetToHead() {
    pause();
    state = const PlaybackState();
  }
}

final playbackControllerProvider = NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);
