import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_context.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../project/controllers/project_controller.dart';
import '../controllers/editor_ui_controller.dart';
import '../models/timeline_ranges.dart';

class EditorTimeline extends ConsumerStatefulWidget {
  const EditorTimeline({super.key});
  @override
  ConsumerState<EditorTimeline> createState() => _EditorTimelineState();
}

class _EditorTimelineState extends ConsumerState<EditorTimeline> {
  int _zoom = 1;
  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectControllerProvider);
    final frame = ref.watch(playbackControllerProvider).frame;
    final focused = ref.watch(editorUiControllerProvider).focusedId;
    final total = project.engine.totalFrames;
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Timeline', style: context.type.titleS),
            const Spacer(),
            for (final zoom in [1, 2, 4])
              TextButton(
                onPressed: () => setState(() => _zoom = zoom),
                child: Text(
                  zoom == 1 ? 'Fit' : '$zoom×',
                  style: TextStyle(color: _zoom == zoom ? p.accent : p.muted),
                ),
              ),
          ],
        ),
        LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth * _zoom;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => ref
                    .read(playbackControllerProvider.notifier)
                    .scrubToFraction(d.localPosition.dx / width),
                onHorizontalDragUpdate: (d) => ref
                    .read(playbackControllerProvider.notifier)
                    .scrubToFraction(d.localPosition.dx / width),
                child: SizedBox(
                  width: width,
                  height: 84,
                  child: Stack(
                    children: [
                      for (var i = 0; i <= 5; i++)
                        Positioned(
                          left: (width - 60) * i / 5,
                          top: 0,
                          child: Text(
                            formatTimecode(
                              total * i / 5,
                              project.engine.fps,
                            ).substring(3, 8),
                            style: context.type.mono.copyWith(fontSize: 10),
                          ),
                        ),
                      for (final r in timelineRanges(project))
                        Positioned(
                          left: width * r.start / total,
                          width: (width * (r.end - r.start) / total).clamp(
                            1,
                            width,
                          ),
                          top: 24,
                          height: 44,
                          child: Tooltip(
                            message:
                                '${r.label} · ${formatTimecode(r.start, project.engine.fps)} → ${formatTimecode(r.end, project.engine.fps)}',
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: r.blockId == focused
                                    ? p.accentWash
                                    : p.glass,
                                border: Border.all(
                                  color: r.blockId == focused
                                      ? p.accentSolid
                                      : p.line,
                                ),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                r.label,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: context.type.mono.copyWith(fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: total <= 0
                            ? 0
                            : (width * frame / total).clamp(0, width - 2),
                        top: 20,
                        bottom: 0,
                        child: Container(width: 2, color: p.accentSolid),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
