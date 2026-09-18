import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../data/repositories/template_repository.dart';
import '../../format/screens/format_screen.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../project/controllers/project_controller.dart';
import '../widgets/template_card.dart';

/// Step 1 of the new-project flow (§10 of the brief): a genuinely useful
/// starting-template chooser, never a blank canvas.
///
/// Crash recovery lives on the library screen, where it can be driven by
/// what is actually on disk rather than a hardcoded banner.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void goToFormat() {
      ref.read(playbackControllerProvider.notifier).resetToHead();
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FormatScreen()));
    }

    return Scaffold(
      backgroundColor: EcColors.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: EcColors.surfaceCanvas,
        foregroundColor: EcColors.textPrimary,
        title: const Text('New project', style: TextStyle(fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(EcSpace.s4, EcSpace.s4, EcSpace.s4, EcSpace.s6),
          children: [
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
            for (final t in kProjectTemplates)
              Padding(
                padding: const EdgeInsets.only(bottom: EcSpace.s3),
                child: TemplateCard(
                  template: t,
                  onTap: () {
                    ref.read(projectControllerProvider.notifier).createFromTemplate(t);
                    goToFormat();
                  },
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(EcRadius.lg),
              onTap: () {
                ref.read(projectControllerProvider.notifier).createEmpty();
                goToFormat();
              },
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(EcRadius.lg),
                  border: Border.all(color: EcColors.borderStrong),
                ),
                child: const Text('Start empty', style: TextStyle(fontSize: 14, color: EcColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
