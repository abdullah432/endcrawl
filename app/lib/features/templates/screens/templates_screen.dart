import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../appendix/screens/appendix_screen.dart';
import '../../format/screens/format_screen.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../project/controllers/project_controller.dart';
import '../../project/repository/template_repository.dart';
import '../widgets/recovery_banner.dart';
import '../widgets/template_card.dart';

/// Screen 1 of the new-project flow (§10 of the brief): a genuinely useful
/// starting-template chooser, never a blank canvas, plus crash recovery.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectControllerProvider);

    return Scaffold(
      backgroundColor: EcColors.surfaceCanvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(EcSpace.s4, EcSpace.s4, EcSpace.s3, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ENDCRAWL',
                      style: TextStyle(
                        fontFamily: EcFonts.archivoNarrow,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: 4.5,
                        color: EcColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Design system',
                    icon: const Icon(Icons.palette_outlined, color: EcColors.textTertiary, size: 20),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AppendixScreen()),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(EcSpace.s4, EcSpace.s5, EcSpace.s4, EcSpace.s6),
                children: [
                  const Text(
                    'NEW PROJECT',
                    style: TextStyle(fontSize: 11, letterSpacing: 2.2, color: EcColors.textTertiary),
                  ),
                  const SizedBox(height: EcSpace.s2),
                  const Text(
                    'Pick a starting point.\nChange anything later.',
                    style: TextStyle(
                      fontFamily: EcFonts.archivo,
                      fontWeight: FontWeight.w600,
                      fontSize: 26,
                      height: 1.14,
                      letterSpacing: -0.4,
                      color: EcColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: EcSpace.s5),
                  if (project.hasRecoverableProject)
                    RecoveryBanner(
                      onOpen: () {
                        ref.read(projectControllerProvider.notifier).openRecovered();
                        ref.read(playbackControllerProvider.notifier).resetToHead();
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FormatScreen()));
                      },
                      onDiscard: () => ref.read(projectControllerProvider.notifier).discardRecovery(),
                    ),
                  for (final t in kProjectTemplates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: EcSpace.s3),
                      child: TemplateCard(
                        template: t,
                        onTap: () {
                          ref.read(projectControllerProvider.notifier).loadTemplate(t);
                          ref.read(playbackControllerProvider.notifier).resetToHead();
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FormatScreen()));
                        },
                      ),
                    ),
                  InkWell(
                    borderRadius: BorderRadius.circular(EcRadius.lg),
                    onTap: () {
                      ref.read(projectControllerProvider.notifier).startEmpty();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FormatScreen()));
                    },
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(EcRadius.lg),
                        border: Border.all(color: EcColors.borderStrong, style: BorderStyle.solid),
                      ),
                      child: const Text('Start empty', style: TextStyle(fontSize: 14, color: EcColors.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
