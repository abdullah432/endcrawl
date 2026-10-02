import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/entitlement.dart';
import '../../plan/controllers/editable_projects.dart';
import '../../plan/controllers/plan_controller.dart';
import '../../plan/screens/pro_sheet.dart';
import '../../project/controllers/project_controller.dart';

/// Whether the open project is read-only on the free plan.
final editorReadOnlyProvider = Provider<bool>((ref) {
  final id = ref.watch(projectControllerProvider.select((s) => s.project.id));
  return ref.watch(readOnlyProjectIdsProvider).contains(id);
});

/// Above the block list when the free plan can't edit this project: what
/// happened, what still works, and the two ways out — make this the one
/// project that stays editable, or try Pro.
class ReadOnlyBanner extends ConsumerWidget {
  const ReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(editorReadOnlyProvider)) return const SizedBox.shrink();
    final trial = ref.watch(planControllerProvider.select((s) => s.offers.any((o) => o.hasTrial)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: EcNotice(
        tone: EcTone.accent,
        icon: Icons.lock_outline_rounded,
        title: 'Read-only on the free plan',
        body: 'The free plan keeps ${Entitlement.freeProjectsInWords} editable. This one still plays and exports.',
        actions: [
          EcButton.secondary(
            label: 'Edit this one instead',
            size: EcButtonSize.small,
            onPressed: () => _switch(context, ref),
          ),
          EcButton(
            label: trial ? 'Try Pro free' : 'Go Pro',
            size: EcButtonSize.small,
            onPressed: () => ProSheet.show(context),
          ),
        ],
      ),
    );
  }

  Future<void> _switch(BuildContext context, WidgetRef ref) async {
    final confirmed = await showEcSheet<bool>(
      context,
      builder: (sheet) {
        final t = sheet.type;
        return EcSheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EcHeadline('Edit this one', emphasis: 'instead?', style: t.displayM.copyWith(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                'Your least recently edited project becomes read-only. Nothing is deleted, and you can switch back any time.',
                style: t.body.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 18),
              EcButton(label: 'Edit this one', onPressed: () => Navigator.of(sheet).pop(true)),
              const SizedBox(height: 6),
              EcButton.text(label: 'Keep it read-only', onPressed: () => Navigator.of(sheet).pop(false)),
            ],
          ),
        );
      },
    );
    if (confirmed != true) return;
    await ref.read(projectControllerProvider.notifier).keepEditable();
    if (context.mounted) showEcToast(context, 'You can edit this project now');
  }
}

/// A row's tap on a read-only project: say why nothing opens.
void explainReadOnly(BuildContext context) =>
    showEcToast(context, 'Read-only on the free plan — ${Entitlement.freeProjectsInWords} stay editable');
