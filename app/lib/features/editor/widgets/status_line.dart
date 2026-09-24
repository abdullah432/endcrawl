import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../project/controllers/project_controller.dart';

/// Where the roll stands: judder-free and readable, juddering, or too fast
/// to read. Judder wins when both apply — it is the one a new runtime fixes.
enum RollHealth { clean, judder, tooFast }

RollHealth rollHealth(ProjectState project) {
  final e = project.engine;
  if (!e.clean) return RollHealth.judder;
  if (!e.readable) return RollHealth.tooFast;
  return RollHealth.clean;
}

/// "24 fps · 4 px/frame · clean · 02:41" — the facts timing rests on.
String rollStatusText(ProjectState project, {bool withTotal = true}) {
  final e = project.engine;
  final health = switch (rollHealth(project)) {
    RollHealth.clean => 'clean',
    RollHealth.judder => 'judder',
    RollHealth.tooFast => 'too fast',
  };
  final runtime = formatRuntime(project.runtime);
  return [
    formatFps(e.fps),
    '${formatPpf(e.ppf)} px/frame',
    health,
    withTotal ? '$runtime total' : runtime,
  ].join(' · ');
}

/// The status line above the scrubber (3.1): a coloured dot and the roll's
/// facts — or, while the last save was refused, why, so a project can't
/// quietly fail to reach the account. [onBlack] is the landscape monitor's
/// frosted pill (3.4).
class StatusLine extends StatelessWidget {
  final ProjectState project;
  final bool onBlack;

  const StatusLine({super.key, required this.project, this.onBlack = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final unsaved = project.saveState == SaveState.failed;
    final ok = !unsaved && rollHealth(project) == RollHealth.clean;
    final dot = ok ? (onBlack ? p.okOnBlack : p.ok) : (onBlack ? p.warnOnBlack : p.warnFill);
    final ink = onBlack ? Colors.white : (ok ? p.ink2 : p.warn);

    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              unsaved
                  ? 'Not saved · ${project.saveFailure?.message ?? 'try again'}'
                  : rollStatusText(project, withTotal: !onBlack),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.mono.copyWith(fontSize: 10, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}
