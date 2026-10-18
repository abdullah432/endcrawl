import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import 'project_actions_sheet.dart';

/// T1.3 — a project's actions on a tablet, from its "···": the library
/// dims, the card lifts in place with an accent outline, and the menu
/// anchors under it. Open leads; Delete is red and set apart.
///
/// [cell] is the card's own context, for where it sits; [card] is the
/// card again, drawn lifted over the dimmed library.
Future<ProjectAction?> showTabletProjectMenu(BuildContext cell, {required Widget card}) {
  final box = cell.findRenderObject()! as RenderBox;
  final navigator = Navigator.of(cell);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  return navigator.push(
    PageRouteBuilder<ProjectAction>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: 'Close project actions',
      barrierColor: cell.palette.ink.withValues(alpha: .38),
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, _, _) => _Menu(rect: rect, card: card, bounds: overlay.size),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _Menu extends StatelessWidget {
  final Rect rect;
  final Widget card;
  final Size bounds;

  const _Menu({required this.rect, required this.card, required this.bounds});

  static const _width = 270.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    void pick(ProjectAction action) => Navigator.of(context).pop(action);
    Widget entry(ProjectAction action, String label, {bool lead = false, bool destructive = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: lead ? p.tint : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => pick(action),
          child: Container(
            height: 46,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              label,
              style: t.row.copyWith(
                fontSize: 14.5,
                fontWeight: lead || destructive ? FontWeight.w600 : FontWeight.w500,
                color: destructive ? p.warn : p.ink,
              ),
            ),
          ),
        ),
      ),
    );

    // Under the card, leaning right of its centre; kept on screen.
    final left = (rect.left + rect.width * .45).clamp(16.0, bounds.width - _width - 16);
    final below = rect.bottom + 10;
    const menuHeight = 8 + 46 * 5 + 17 + 8;
    final top = below + menuHeight > bounds.height - 16 ? rect.top - menuHeight - 10 : below;

    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: p.accentSolid, width: 1.5),
            ),
            child: IgnorePointer(child: card),
          ),
        ),
        Positioned(
          left: left,
          top: top.clamp(16.0, bounds.height - menuHeight - 16),
          width: _width,
          child: Material(
            color: p.surface,
            elevation: 16,
            shadowColor: const Color(0x66000000),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  entry(ProjectAction.open, 'Open', lead: true),
                  entry(ProjectAction.rename, 'Rename…'),
                  entry(ProjectAction.duplicate, 'Duplicate'),
                  entry(ProjectAction.export, 'Export…'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(height: 1, color: p.line),
                  ),
                  entry(ProjectAction.delete, 'Delete…', destructive: true),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
