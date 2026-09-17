import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../project/controllers/project_controller.dart';
import '../../project/models/roll_engine.dart';
import '../controllers/editor_ui_controller.dart';

/// Non-blocking warning when a runtime lands on a fractional px/frame rate
/// or pushes a line below the 3.0s readability floor — never silently
/// renders an unreadable roll (§3 of the brief).
class WarnBanner extends ConsumerWidget {
  const WarnBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectControllerProvider);
    final ui = ref.watch(editorUiControllerProvider);
    final e = project.engine;
    final show = (!e.clean || !e.readable) && !ui.warnDismissed;
    if (!show) return const SizedBox.shrink();

    final text = !e.readable
        ? 'At this runtime a line is on screen for ${e.dwellSeconds.toStringAsFixed(1)}s — below the 3.0s readability floor. Lengthen the roll or trim lines.'
        : 'This runtime lands on ${e.ppf.toStringAsFixed(3)} px per frame. Fractional rates strobe on playback.';

    final controller = ref.read(projectControllerProvider.notifier);
    final snaps = engineSnaps(e);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: EcSpace.s4, vertical: EcSpace.s2),
      padding: const EdgeInsets.symmetric(horizontal: EcSpace.s3, vertical: 10),
      decoration: BoxDecoration(
        color: EcColors.warnWash,
        border: Border.all(color: EcColors.warn.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(EcRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 12, height: 1.35, color: EcColors.textPrimary)),
          const SizedBox(height: EcSpace.s2),
          Wrap(
            spacing: EcSpace.s2,
            runSpacing: EcSpace.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final s in snaps)
                Material(
                  color: EcColors.surfaceHi,
                  borderRadius: BorderRadius.circular(EcRadius.full),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(EcRadius.full),
                    onTap: () {
                      controller.applySnap(s.$1);
                      ref.read(editorUiControllerProvider.notifier).resetWarn();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: EcSpace.s3, vertical: 8),
                      child: Text(formatTimecode(s.$2, e.fps), style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 11, color: EcColors.textPrimary)),
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => ref.read(editorUiControllerProvider.notifier).dismissWarn(),
                style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: EcSpace.s2)),
                child: const Text('Ignore', style: TextStyle(fontSize: 11, color: EcColors.textTertiary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
