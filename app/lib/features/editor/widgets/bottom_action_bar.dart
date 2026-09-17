import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../project/controllers/project_controller.dart';
import '../../project/models/roll_engine.dart';
import '../controllers/editor_ui_controller.dart';

/// Primary actions live in the bottom third, thumb-first (hard constraint
/// §4 of the brief): Add block, Paste & split, Timing, Export.
class BottomActionBar extends ConsumerWidget {
  const BottomActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(projectControllerProvider.select((s) => s.engine));
    final editorUi = ref.read(editorUiControllerProvider.notifier);
    final shortDur = formatTimecode(e.totalFrames, e.fps).substring(3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(EcSpace.s3, EcSpace.s2, EcSpace.s3, EcSpace.s2),
      child: Row(
        children: [
          Expanded(child: _action('+', 'Block', () => editorUi.openSheet(EditorSheet.add))),
          const SizedBox(width: EcSpace.s2),
          Expanded(child: _action('⇥', 'Paste', () => editorUi.openSheet(EditorSheet.paste))),
          const SizedBox(width: EcSpace.s2),
          Expanded(child: _action(shortDur, 'Timing', () => editorUi.openSheet(EditorSheet.duration), mono: true)),
          const SizedBox(width: EcSpace.s2),
          Expanded(
            flex: 5,
            child: Material(
              color: EcColors.accentPrimary,
              borderRadius: BorderRadius.circular(EcRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(EcRadius.md),
                onTap: () => editorUi.openSheet(EditorSheet.export),
                child: const SizedBox(
                  height: 52,
                  child: Center(child: Text('Export', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: EcColors.accentInk))),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(String glyph, String label, VoidCallback onTap, {bool mono = false}) {
    return Material(
      color: EcColors.surfaceRaised,
      borderRadius: BorderRadius.circular(EcRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(EcRadius.md),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.md)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  glyph,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(fontSize: mono ? 10.5 : 14, fontFamily: mono ? EcFonts.mono : null, color: EcColors.textPrimary),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: EcColors.textPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
