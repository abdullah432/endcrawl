import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_credit_frame.dart';
import '../../../core/widgets/ec_dashed_border.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../domain/models/canvas_format.dart';
import '../controllers/new_project_controller.dart';

/// The templates as rows, plus "Start empty" — the same list on the empty
/// library (1.2) and the new-project sheet (2.1).
///
/// With [selectedId] null a tap picks straight away (1.2); otherwise the
/// tapped row is marked and the caller's Continue picks it (2.1). The empty
/// option is reported as `null`.
class TemplateList extends ConsumerWidget {
  final String? selectedId;
  final bool selectable;
  final ValueChanged<ProjectTemplate?> onPick;

  const TemplateList({super.key, required this.onPick, this.selectedId, this.selectable = false});

  static const emptyId = 'empty';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(newProjectControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final template in kProjectTemplates) ...[
          _TemplateRow(
            template: template,
            blockCount: controller.blockCountOf(template),
            selected: selectable && selectedId == template.id,
            onTap: () => onPick(template),
          ),
          const SizedBox(height: 10),
        ],
        EcDashedBorder(
          color: selectable && selectedId == emptyId ? context.palette.accentSolid : null,
          onTap: () => onPick(null),
          child: SizedBox(
            height: 52,
            child: Center(child: Text('Start empty', style: context.type.row.copyWith(fontSize: 14, color: context.palette.ink2))),
          ),
        ),
      ],
    );
  }
}

class _TemplateRow extends StatelessWidget {
  final ProjectTemplate template;
  final int blockCount;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateRow({required this.template, required this.blockCount, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final format = CanvasFormat.byId(template.formatId);
    final shape = BorderRadius.circular(EcRadius.card);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: EcMotion.fast,
        decoration: BoxDecoration(
          color: selected ? p.surface : p.glass,
          borderRadius: shape,
          border: Border.all(color: selected ? p.accentSolid : p.glassEdge, width: selected ? 1.5 : 1),
          boxShadow: p.rowShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  EcFrameThumb(portrait: format.isPortrait, wideFirst: template.id != 'short'),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(template.name, style: t.titleS.copyWith(fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(template.description, style: t.caption.copyWith(fontSize: 12)),
                        const SizedBox(height: 5),
                        Text(
                          '${formatFps(template.fps)} · ${format.aspect} · ${plural(blockCount, 'block')}',
                          style: t.mono.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(gradient: p.primary, shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded, size: 15, color: p.onInk),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
