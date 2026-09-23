import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_credit_frame.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../domain/models/canvas_format.dart';
import '../../../domain/models/project.dart';

enum ProjectAction { open, duplicate, rename, delete }

/// 1.3 — what you can do with a project.
///
/// Repeats the project's name at the top, so a mis-tap is caught before a
/// destructive action, and shows what Duplicate costs on the free plan.
class ProjectActionsSheet extends StatelessWidget {
  final ProjectSummary summary;

  /// Free slots left, or null on an unlimited plan.
  final int? slotsLeft;

  const ProjectActionsSheet({super.key, required this.summary, required this.slotsLeft});

  static Future<ProjectAction?> show(BuildContext context, ProjectSummary summary, {int? slotsLeft}) {
    return showEcSheet<ProjectAction>(
      context,
      builder: (_) => ProjectActionsSheet(summary: summary, slotsLeft: slotsLeft),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    final format = CanvasFormat.byId(summary.settings.formatId);
    final meta = [
      formatFps(summary.settings.fps),
      format.aspect,
      if (summary.runtime != null) formatRuntime(summary.runtime!),
      plural(summary.blockCount, 'block'),
    ].join(' · ');

    final duplicateDetail = switch (slotsLeft) {
      null => null,
      0 => 'No free slots — Pro removes the cap',
      1 => 'Uses your last free slot',
      final n => 'Uses one of $n free slots',
    };

    void pick(ProjectAction a) => Navigator.of(context).pop(a);

    return EcSheet(
      header: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
        child: Row(
          children: [
            EcFrameThumb(portrait: format.isPortrait),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary.title, style: t.displayS, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(meta, style: t.mono.copyWith(fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: EcButton.secondary(label: 'Cancel', size: EcButtonSize.medium, expand: true, onPressed: () => Navigator.of(context).pop()),
      ),
      child: Column(
        children: [
          EcSheetAction(icon: Icons.play_arrow_rounded, label: 'Open', onTap: () => pick(ProjectAction.open)),
          EcSheetAction(
            icon: Icons.copy_rounded,
            label: 'Duplicate',
            detail: duplicateDetail,
            onTap: slotsLeft == 0 ? null : () => pick(ProjectAction.duplicate),
          ),
          EcSheetAction(icon: Icons.edit_outlined, label: 'Rename', onTap: () => pick(ProjectAction.rename)),
          Divider(height: 13, indent: 12, endIndent: 12, color: p.line),
          EcSheetAction(
            icon: Icons.backspace_outlined,
            label: 'Delete project',
            destructive: true,
            onTap: () => pick(ProjectAction.delete),
          ),
        ],
      ),
    );
  }
}
