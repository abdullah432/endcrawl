import 'package:flutter/material.dart';

import '../../../core/theme/ec_palette.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_credit_frame.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/project.dart';
import '../../../domain/models/render_summary.dart';
import '../controllers/library_controller.dart';

/// A project on the library (1.1): a credit frame showing its first card,
/// numbered like a reel, with its runtime, frame rate and last edit.
///
/// Two variants from the design: [highlighted] is the fresh copy after a
/// duplicate (1.7), with Open and Rename side by side so two renders never
/// end up with the same name; [onDelete] replaces "···" with a delete
/// button while the user is freeing a slot (1.6).
class ProjectCard extends StatelessWidget {
  final LibraryItem item;
  final DateTime now;
  final double frameHeight;
  final bool highlighted;
  final double? renderProgress;
  final VoidCallback onOpen;
  final VoidCallback onMore;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const ProjectCard({
    super.key,
    required this.item,
    required this.now,
    required this.onOpen,
    required this.onMore,
    this.frameHeight = 120,
    this.highlighted = false,
    this.renderProgress,
    this.onRename,
    this.onDelete,
  });

  ProjectSummary get _s => item.summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final format = _s.settings.format;
    final (status, statusColor) = _status(p);

    final meta = [
      if (_s.runtime != null) formatRuntime(_s.runtime!),
      formatFps(_s.settings.fps),
      formatRelativeTime(_s.updatedAt, now: now),
    ].join(' · ');

    return Semantics(
      button: true,
      label: '${_s.title}, reel ${item.reel}',
      child: EcGlassCard(
        highlighted: highlighted,
        onTap: highlighted ? null : onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EcCreditFrame(
              height: highlighted ? 110 : frameHeight,
              status: status,
              statusColor: statusColor,
              corner: format.aspect,
              progress: renderProgress,
              child: highlighted
                  ? Text('NO RENDER YET', style: t.pill.copyWith(fontSize: 10, color: Colors.white.withValues(alpha: 0.62)))
                  : _preview(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 8, 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(item.reel.toString().padLeft(2, '0'),
                          style: t.reel.copyWith(color: highlighted ? p.accentSolid : p.muted)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_s.title, style: t.titleM, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(meta, style: t.mono.copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (!highlighted)
                        onDelete != null
                            ? EcButton(
                                label: 'Delete',
                                variant: EcButtonVariant.destructive,
                                size: EcButtonSize.small,
                                onPressed: onDelete,
                              )
                            : EcCircleButton.tint(icon: Icons.more_horiz_rounded, tooltip: 'Project actions', onPressed: onMore),
                    ],
                  ),
                  if (highlighted) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: EcButton(label: 'Open', size: EcButtonSize.medium, onPressed: onOpen)),
                        const SizedBox(width: 8),
                        EcButton.secondary(label: 'Rename', size: EcButtonSize.medium, onPressed: onRename),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String?, Color?) _status(EcPalette p) {
    if (highlighted) return ('Just created', p.accentOnBlack);
    if (renderProgress != null) return ('Rendering ${(renderProgress! * 100).round()}%', p.accentOnBlack);
    return switch (_s.lastRender?.outcome) {
      RenderOutcome.rendered => ('Rendered', p.okOnBlack),
      RenderOutcome.failed => ('Render failed', p.warnOnBlack),
      null => (null, null),
    };
  }

  Widget _preview(BuildContext context) {
    final preview = _s.preview;
    if (preview.isEmpty) {
      return Text('EMPTY ROLL', style: context.type.pill.copyWith(fontSize: 10, color: Colors.white.withValues(alpha: 0.5)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CreditCard(header: preview.header, names: preview.names, nameSize: frameHeight > 130 ? 17 : 13),
    );
  }
}
