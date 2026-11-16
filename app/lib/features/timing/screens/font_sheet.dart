import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ec_choice_card.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../domain/models/credit_face.dart';
import '../../access/controllers/web_access.dart';
import '../../access/widgets/locked_dialog.dart';
import '../../project/controllers/project_controller.dart';

class FontSheet extends ConsumerWidget {
  const FontSheet({super.key});

  static Future<void> show(BuildContext context) async {
    if (lockedOnWeb(context, LockedAction.look)) return;
    await showEcSheet<void>(context, builder: (_) => const FontSheet());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectControllerProvider);
    final controller = ref.read(projectControllerProvider.notifier);
    return EcSheet(
      title: 'Credits font',
      maxHeightFraction: .75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Applies to all credits, in the preview and exported video.',
          ),
          const SizedBox(height: 16),
          for (final face in CreditFace.values) ...[
            EcChoiceCard(
              selected: project.face == face,
              semanticLabel: face.displayName,
              onTap: !controller.readOnly
                  ? () => controller.setFace(face)
                  : null,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(face.displayName),
                  const SizedBox(height: 8),
                  Text(
                    'Directed by Maya Okonkwo',
                    style: face.textStyle(
                      size: 22,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
