import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../project/controllers/project_controller.dart';
import '../../project/models/project_settings.dart';
import '../controllers/editor_ui_controller.dart';

class TransportBar extends ConsumerWidget {
  const TransportBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackControllerProvider);
    final playbackCtrl = ref.read(playbackControllerProvider.notifier);
    final settings = ref.watch(projectControllerProvider.select((s) => s.settings));
    final editorUi = ref.read(editorUiControllerProvider.notifier);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _iconBtn(Icons.skip_previous, playbackCtrl.toHead),
            _textBtn('-1f', playbackCtrl.stepBack),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: EcColors.accentPrimary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: playbackCtrl.togglePlay,
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(playback.playing ? Icons.pause : Icons.play_arrow, color: EcColors.accentInk, size: 20),
                  ),
                ),
              ),
            ),
            _textBtn('+1f', playbackCtrl.stepForward),
            _iconBtn(Icons.skip_next, playbackCtrl.toTail),
          ],
        ),
        Row(
          children: [
            _pillBtn(settings.look == RollLook.flat2d ? '2D' : '3D', () => editorUi.openSheet(EditorSheet.look)),
            const SizedBox(width: 4),
            _pillBtn(_bgLabel(settings.background), () => editorUi.openSheet(EditorSheet.background)),
          ],
        ),
      ],
    );
  }

  String _bgLabel(MonitorBackground bg) => switch (bg) {
        MonitorBackground.alpha => 'Alpha',
        MonitorBackground.green => 'Green',
        MonitorBackground.underlay => 'Underlay',
        MonitorBackground.custom => 'Color',
        MonitorBackground.black => 'Black',
      };

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 36,
      height: 40,
      child: IconButton(padding: EdgeInsets.zero, onPressed: onTap, icon: Icon(icon, size: 16, color: EcColors.textSecondary)),
    );
  }

  Widget _textBtn(String label, VoidCallback onTap) {
    return SizedBox(
      width: 38,
      height: 40,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
        child: Text(label, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 11, color: EcColors.textSecondary)),
      ),
    );
  }

  Widget _pillBtn(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EcRadius.full),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(EcRadius.full), border: Border.all(color: EcColors.borderHairline)),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(fontSize: 11, color: EcColors.textSecondary)),
        ),
      ),
    );
  }
}
