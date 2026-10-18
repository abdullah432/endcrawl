import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/ec_credit_frame.dart';
import '../../../domain/models/render_summary.dart';
import '../controllers/library_controller.dart';

/// A project in the tablet and desktop library grid (T1.1, D9): a black
/// credit frame with its status and aspect ratio, then the reel number,
/// the title in serif, and runtime · frame rate beside the last edit.
///
/// The same project as the phone's [ProjectCard], drawn for a grid cell.
/// In the web preview (D7) the status gives way to "▶ Play" and there is no
/// "···": nothing can be renamed, duplicated or deleted there.
class ProjectTile extends StatelessWidget {
  final LibraryItem item;
  final DateTime now;

  /// The credit frame's design height, for sizing the grid cell; the frame
  /// itself fills whatever the cell leaves after the footer.
  final double frameHeight;
  final double? renderProgress;
  final bool highlighted;
  final bool readOnly;
  final bool preview;
  final VoidCallback onOpen;

  /// Called with the "···" button's context, so the action menu can anchor
  /// to it (T1.3). Null hides the button.
  final void Function(BuildContext anchor)? onMore;

  /// The footer's title size and padding, and the credit's name size: the
  /// tablet's big portrait cards (P1.2) set larger ones.
  final double titleSize;
  final double nameSize;
  final EdgeInsets footerPadding;

  /// The "···" button's height; the tablet grid keeps its footer to the
  /// design's line height.
  final double moreHeight;

  /// The footer's height for [titleSize], [footerPadding] and [moreHeight].
  static double footerHeight({double titleSize = 21, EdgeInsets padding = const EdgeInsets.fromLTRB(14, 12, 8, 14), double moreHeight = 32}) =>
      padding.vertical + (titleSize * 1.1 > moreHeight ? titleSize * 1.1 : moreHeight) + 13;

  const ProjectTile({
    super.key,
    required this.item,
    required this.now,
    required this.onOpen,
    this.onMore,
    this.frameHeight = 150,
    this.renderProgress,
    this.highlighted = false,
    this.readOnly = false,
    this.preview = false,
    this.titleSize = 21,
    this.nameSize = 15,
    this.footerPadding = const EdgeInsets.fromLTRB(14, 12, 8, 14),
    this.moreHeight = 32,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final s = item.summary;
    final mono = t.mono.copyWith(fontSize: 10.5, color: p.muted);
    final meta = [if (s.runtime != null) formatRuntime(s.runtime!), formatFps(s.settings.fps)].join(' · ');
    final shape = BorderRadius.circular(22);

    return Semantics(
      button: true,
      label: '${s.title}, reel ${item.reel}',
      child: Container(
        decoration: BoxDecoration(
          // The design's 75 % white over the ground, flattened: a
          // translucent fill would show the drop shadow through it.
          color: Color.alphaBlend(p.surface.withValues(alpha: .75), p.ground),
          borderRadius: shape,
          border: Border.all(color: highlighted ? p.accentSolid : p.glassEdge, width: highlighted ? 1.5 : 1),
          boxShadow: [
            if (highlighted) BoxShadow(color: p.accentWash, spreadRadius: 5),
            ...p.glassShadow,
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The frame takes what the grid cell leaves after the footer,
                // so larger text never overflows the cell.
                Expanded(
                  child: _Frame(item: item, renderProgress: renderProgress, preview: preview, nameSize: nameSize),
                ),
                Padding(
                  padding: footerPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(item.reel.toString().padLeft(2, '0'), style: mono.copyWith(color: p.faint)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.displayS.copyWith(fontSize: titleSize, height: 1.1),
                            ),
                          ),
                          if (readOnly && !preview)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text('READ-ONLY', style: t.pill.copyWith(color: p.muted)),
                            ),
                          if (onMore != null)
                            Builder(
                              builder: (anchor) => IconButton(
                                tooltip: 'Project actions',
                                constraints: BoxConstraints.tightFor(width: 36, height: moreHeight),
                                // A shorter "···" keeps the footer to the design's line (the tablet grid).
                                style: moreHeight < 32
                                    ? const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap)
                                    : null,
                                padding: EdgeInsets.zero,
                                icon: Icon(Icons.more_horiz_rounded, color: p.muted, size: 20),
                                onPressed: () => onMore!(anchor),
                              ),
                            )
                          else
                            SizedBox(height: moreHeight),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(meta, style: mono, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            Text(formatRelativeTime(s.updatedAt, now: now), style: mono),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  final LibraryItem item;
  final double? renderProgress;
  final bool preview;
  final double nameSize;
  const _Frame({required this.item, required this.renderProgress, required this.preview, required this.nameSize});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final s = item.summary;
    final empty = s.preview.isEmpty;
    final (label, dot) = preview
        ? ('▶ PLAY', null)
        : renderProgress != null
        ? ('RENDERING ${(renderProgress! * 100).round()}%', null)
        : switch (s.lastRender?.outcome) {
            RenderOutcome.rendered => ('RENDERED', p.okOnBlack),
            RenderOutcome.failed => ('RENDER FAILED', p.warnOnBlack),
            null => (empty ? 'EMPTY' : 'DRAFT', null),
          };
    return ColoredBox(
      color: p.monitor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: empty
                ? CreditCard(header: 'Title card', names: const ['Untitled'], nameSize: nameSize)
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CreditCard(header: s.preview.header, names: s.preview.names, nameSize: nameSize),
                  ),
          ),
          Positioned(
            left: 12,
            top: 10,
            child: Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dot != null) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(label, style: t.pill.copyWith(fontSize: 9.5, color: Colors.white, letterSpacing: .6)),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Text(
              s.settings.format.aspect,
              style: t.pill.copyWith(fontSize: 9.5, color: Colors.white.withValues(alpha: .6)),
            ),
          ),
          if (renderProgress != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: renderProgress!.clamp(0, 1),
                  heightFactor: 1,
                  child: DecoratedBox(decoration: BoxDecoration(gradient: p.primary)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
