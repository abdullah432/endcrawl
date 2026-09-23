import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/project.dart';

/// 1.5 — confirming a project delete.
///
/// Names the project, counts what leaves with it, says how long undo lasts,
/// and labels the safe option by its outcome: "Keep it".
class DeleteProjectSheet extends StatelessWidget {
  final ProjectSummary summary;

  const DeleteProjectSheet({super.key, required this.summary});

  static Future<bool> confirm(BuildContext context, ProjectSummary summary) async {
    final result = await showEcSheet<bool>(context, builder: (_) => DeleteProjectSheet(summary: summary));
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final renders = summary.lastRender == null ? '' : ' and its finished render';
    return EcSheet(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcIconBadge(Icons.backspace_outlined, destructive: true, size: 52),
          const SizedBox(height: 16),
          EcEyebrow('Delete project', color: p.warn),
          const SizedBox(height: 8),
          EcHeadline('Delete', emphasis: '${summary.title}?', style: t.displayL.copyWith(fontSize: 32, height: 1.05)),
          const SizedBox(height: 10),
          Text(
            '${plural(summary.blockCount, 'block')}, your timing$renders go with it. Nothing is kept on our side.',
            style: t.body.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border.all(color: p.line),
              borderRadius: BorderRadius.circular(EcRadius.field),
            ),
            child: Row(
              children: [
                Text('10s', style: t.mono.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: p.warn)),
                const SizedBox(width: 10),
                Expanded(child: Text('You can undo from the project list for ten seconds.', style: t.bodyS)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          EcButton(
            label: 'Delete project',
            variant: EcButtonVariant.destructive,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          EcButton.secondary(label: 'Keep it', onPressed: () => Navigator.of(context).pop(false)),
        ],
      ),
    );
  }
}
