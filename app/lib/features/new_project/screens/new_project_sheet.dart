import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../bootstrap.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../domain/models/project.dart';
import '../../project/project_navigation.dart';
import '../controllers/new_project_controller.dart';
import '../new_project_flow.dart';
import '../widgets/template_list.dart';

/// 2.1 — "+ New" once projects exist: the same template list as the empty
/// library, as a sheet, with a crash recovery above it when there is one.
class NewProjectSheet extends ConsumerStatefulWidget {
  /// The reel number the new project will take — "slot 3 of 3".
  final String slotLabel;

  const NewProjectSheet({super.key, required this.slotLabel});

  static Future<void> show(BuildContext context, {required String slotLabel}) {
    return showEcSheet<void>(context, builder: (_) => NewProjectSheet(slotLabel: slotLabel));
  }

  @override
  ConsumerState<NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends ConsumerState<NewProjectSheet> {
  String _selected = kProjectTemplates.first.id;

  ProjectTemplate? get _template =>
      _selected == TemplateList.emptyId ? null : kProjectTemplates.firstWhere((t) => t.id == _selected);

  void _continue() {
    final navigator = Navigator.of(context);
    final template = _template;
    navigator.pop();
    startNewProject(navigator.context, template);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final recovery = ref.watch(recoveryCandidateProvider).value;

    return EcSheet(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EcEyebrow('New project · ${widget.slotLabel}'),
                  const SizedBox(height: 8),
                  EcHeadline('Pick a', emphasis: 'starting point.', style: t.displayL.copyWith(fontSize: 32)),
                ],
              ),
            ),
            EcCircleButton.tint(
              icon: Icons.close_rounded,
              size: 34,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: EcButton(label: 'Continue', onPressed: _continue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (recovery != null) ...[
            _RecoveryCard(summary: recovery),
            const SizedBox(height: 18),
          ],
          const EcSectionLabel('Templates'),
          TemplateList(
            selectable: true,
            selectedId: _selected,
            onPick: (template) => setState(() => _selected = template?.id ?? TemplateList.emptyId),
          ),
        ],
      ),
    );
  }
}

class _RecoveryCard extends ConsumerWidget {
  final ProjectSummary summary;
  const _RecoveryCard({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final now = ref.watch(clockProvider)();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.accentWash,
        border: Border.all(color: p.accentLine),
        borderRadius: BorderRadius.circular(EcRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcEyebrow('Recovered after crash', color: p.accent),
          const SizedBox(height: 6),
          Text(summary.title, style: t.titleM),
          const SizedBox(height: 2),
          Text(
            '${plural(summary.blockCount, 'block')} · autosaved ${formatRelativeTime(summary.updatedAt, now: now)}',
            style: t.caption.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: EcButton(
                  label: 'Open recovered',
                  size: EcButtonSize.medium,
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    openStoredProject(navigator.context, summary.id);
                  },
                ),
              ),
              const SizedBox(width: 8),
              EcButton.secondary(
                label: 'Discard',
                size: EcButtonSize.medium,
                onPressed: () => ref.read(newProjectControllerProvider).dismissRecovery(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
