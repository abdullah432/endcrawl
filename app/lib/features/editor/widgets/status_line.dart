import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../project/controllers/project_controller.dart';
import '../../project/models/canvas_format.dart';
import '../../project/models/roll_engine.dart';

/// The persistent, quiet status readout: format · fps · duration · judder
/// state (§8 of the brief).
class StatusLine extends StatelessWidget {
  final ProjectState project;
  final bool dense;

  const StatusLine({super.key, required this.project, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final e = project.engine;
    final sub = project.settings.formatId == 'custom'
        ? '${project.settings.customW}×${project.settings.customH}'
        : CanvasFormat.byId(project.settings.formatId).sub;
    final rate = e.clean ? 'judder-free' : '${e.ppf.toStringAsFixed(2)} px/f';
    final text = '$sub · ${project.settings.fps} fps · ${formatTimecode(e.totalFrames, e.fps)} · $rate';
    final dotColor = e.clean ? (e.readable ? EcColors.accentPrimary : EcColors.warn) : EcColors.warn;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: EcSpace.s2),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 9.5, color: EcColors.textTertiary),
          ),
        ),
      ],
    );
  }
}
