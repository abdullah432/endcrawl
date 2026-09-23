import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/orientations.dart';
import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../monitor/widgets/monitor_view.dart';
import '../../project/controllers/project_controller.dart';
import 'scrub_bar.dart';
import 'status_line.dart';

/// 3.4 — turning the phone opens a full-bleed review monitor. A review
/// mode, not a project setting: the chrome is frosted glass on black and
/// fades two seconds after the last touch; a tap brings it back.
class LandscapeMonitor extends ConsumerStatefulWidget {
  const LandscapeMonitor({super.key});

  @override
  ConsumerState<LandscapeMonitor> createState() => _LandscapeMonitorState();
}

class _LandscapeMonitorState extends ConsumerState<LandscapeMonitor> {
  static const _linger = Duration(seconds: 2);
  bool _chrome = true;
  Timer? _fade;

  @override
  void initState() {
    super.initState();
    _wake();
  }

  @override
  void dispose() {
    _fade?.cancel();
    super.dispose();
  }

  void _wake() {
    _fade?.cancel();
    if (!_chrome) setState(() => _chrome = true);
    _fade = Timer(_linger, () {
      if (mounted) setState(() => _chrome = false);
    });
  }

  /// Back to editing without waiting for the phone to turn: pins portrait
  /// for the rest of this editor session, so the monitor doesn't reopen
  /// while the phone is still sideways.
  void _exit() {
    ref.read(playbackControllerProvider.notifier).pause();
    SystemChrome.setPreferredOrientations(kPortraitOnly);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final project = ref.watch(projectControllerProvider);
    final playing = ref.watch(playbackControllerProvider.select((s) => s.playing));
    final frame = ref.watch(playbackControllerProvider.select((s) => s.frame));
    final playback = ref.read(playbackControllerProvider.notifier);

    return Listener(
      onPointerDown: (_) => _wake(),
      behavior: HitTestBehavior.translucent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          const MonitorView(),
          IgnorePointer(
            ignoring: !_chrome,
            child: AnimatedOpacity(
              opacity: _chrome ? 1 : 0,
              duration: EcMotion.slow,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: _Frost(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              child: StatusLine(project: project, onBlack: true),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(caps('Rotate back to edit'), style: t.eyebrow.copyWith(color: Colors.white.withValues(alpha: .7))),
                        ],
                      ),
                      const Spacer(),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: _Frost(
                          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                          child: Row(
                            children: [
                              Tooltip(
                                message: playing ? 'Pause' : 'Play',
                                child: Material(
                                  type: MaterialType.transparency,
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  child: Ink(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: p.primary),
                                    child: InkWell(
                                      onTap: playback.togglePlay,
                                      child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: p.onInk, size: 20),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 104,
                                child: Text(formatTimecode(frame, project.engine.fps),
                                    style: t.mono.copyWith(fontSize: 13, color: Colors.white)),
                              ),
                              const Expanded(child: ScrubTrack(onBlack: true)),
                              const SizedBox(width: 16),
                              TextButton(
                                onPressed: _exit,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.white.withValues(alpha: .16),
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: const StadiumBorder(),
                                  textStyle: t.bodyS.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                child: const Text('Exit'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted glass on black: white at 14 %, a faint edge, and a blur.
class _Frost extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Frost({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(EcRadius.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(EcRadius.pill),
            border: Border.all(color: Colors.white.withValues(alpha: .2)),
          ),
          child: child,
        ),
      ),
    );
  }
}
