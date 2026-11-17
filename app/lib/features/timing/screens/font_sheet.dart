import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../domain/models/credit_face.dart';
import '../../access/controllers/web_access.dart';
import '../../access/widgets/locked_dialog.dart';
import '../../project/controllers/project_controller.dart';

/// 5.4 — the credits font. The same sheet pattern as Monitor look (5.2):
/// the monitor stays unscrimmed above, so a tap shows the new face on the
/// real roll. Each row previews its face on a black tile, as it renders.
class FontSheet extends ConsumerWidget {
  const FontSheet({super.key});

  static Future<void> show(BuildContext context) async {
    if (lockedOnWeb(context, LockedAction.look)) return;
    await showEcSheet<void>(context, scrim: false, builder: (_) => const FontSheet());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectControllerProvider);
    final controller = ref.read(projectControllerProvider.notifier);
    final t = context.type;
    final p = context.palette;
    return EcSheet(
      title: 'Credits font',
      maxHeightFraction: .75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Applies to every block, in the preview and the export.',
              style: t.bodyS.copyWith(color: p.muted),
            ),
          ),
          const SizedBox(height: 14),
          for (final face in CreditFace.values) ...[
            _FaceRow(
              face: face,
              selected: project.face == face,
              onTap: controller.readOnly ? null : () => controller.setFace(face),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// One face: a preview tile, the style and family names, and a radio
/// check. Selected matches the yearly plan on 6.5 — white card, accent
/// ring and a filled check.
class _FaceRow extends StatelessWidget {
  final CreditFace face;
  final bool selected;
  final VoidCallback? onTap;

  const _FaceRow({required this.face, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final shape = BorderRadius.circular(18);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      enabled: onTap != null,
      label: face.displayName,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: EcMotion.fast,
        decoration: BoxDecoration(
          color: selected ? p.surface : p.glass,
          borderRadius: shape,
          border: Border.all(color: selected ? p.accentSolid : p.line, width: selected ? 1.5 : 1),
          boxShadow: selected ? [BoxShadow(color: p.accentWash, spreadRadius: 4)] : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 78),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                child: Row(
                  children: [
                    _Preview(face: face),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(face.label, style: t.titleS),
                          const SizedBox(height: 3),
                          Text(face.family, style: t.mono.copyWith(letterSpacing: 11 * .06)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _RadioMark(selected: selected),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Directed by / Maya Okonkwo" on black, centred with even side padding
/// so the name never touches the tile's edge.
class _Preview extends StatelessWidget {
  final CreditFace face;
  const _Preview({required this.face});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              caps('Directed by'),
              maxLines: 1,
              style: face.textStyle(size: 5, color: Colors.white.withValues(alpha: .55), letterSpacing: 5 * .24),
            ),
            const SizedBox(height: 5),
            Text(
              caps('Maya Okonkwo'),
              maxLines: 1,
              style: face.textStyle(size: 8, weight: FontWeight.w600, letterSpacing: 8 * .1),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  final bool selected;
  const _RadioMark({required this.selected});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected ? p.primary : null,
        border: selected ? null : Border.all(color: p.line2, width: 1.5),
      ),
      child: selected ? Icon(Icons.check_rounded, size: 14, color: p.onInk) : null,
    );
  }
}
