import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../monitor/widgets/monitor_view.dart';
import '../../project/controllers/project_controller.dart';
import '../controllers/editor_ui_controller.dart';
import '../widgets/block_list.dart';
import '../widgets/bottom_action_bar.dart';
import '../widgets/landscape_monitor.dart';
import '../widgets/scrub_bar.dart';
import '../widgets/sheets/add_block_sheet.dart';
import '../widgets/sheets/background_sheet.dart';
import '../widgets/sheets/block_editor_sheet.dart';
import '../widgets/sheets/duration_sheet.dart';
import '../widgets/sheets/export_sheet.dart';
import '../widgets/sheets/look_sheet.dart';
import '../widgets/sheets/paste_sheet.dart';
import '../widgets/status_line.dart';
import '../widgets/transport_bar.dart';
import '../widgets/warn_banner.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(editorUiControllerProvider.select((s) => s.sheet), (prev, next) {
      if (next == EditorSheet.none) return;
      final blockId = ref.read(editorUiControllerProvider).sheetBlockId;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => switch (next) {
          EditorSheet.add => const AddBlockSheet(),
          EditorSheet.look => const LookSheet(),
          EditorSheet.background => const BackgroundSheet(),
          EditorSheet.duration => const DurationSheet(),
          EditorSheet.paste => const PasteSheet(),
          EditorSheet.export => const ExportSheet(),
          EditorSheet.block => BlockEditorSheet(blockId: blockId ?? ''),
          EditorSheet.none => const SizedBox.shrink(),
        },
      ).whenComplete(() => ref.read(editorUiControllerProvider.notifier).closeSheet());
    });

    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return const Scaffold(backgroundColor: Colors.black, body: LandscapeMonitor());
        }
        return _portrait(context);
      },
    );
  }

  Widget _portrait(BuildContext context) {
    final project = ref.watch(projectControllerProvider);
    final controller = ref.read(projectControllerProvider.notifier);
    final ui = ref.watch(editorUiControllerProvider);

    return Scaffold(
      backgroundColor: EcColors.surfaceCanvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: EcSpace.s3, vertical: EcSpace.s2),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.chevron_left, color: EcColors.textSecondary),
                  ),
                  Expanded(
                    child: Text(project.name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: EcColors.textPrimary)),
                  ),
                  IconButton(
                    onPressed: controller.canUndo ? controller.undo : null,
                    icon: Icon(Icons.undo, size: 18, color: controller.canUndo ? EcColors.textSecondary : EcColors.textDisabled),
                  ),
                  IconButton(
                    onPressed: controller.canRedo ? controller.redo : null,
                    icon: Icon(Icons.redo, size: 18, color: controller.canRedo ? EcColors.textSecondary : EcColors.textDisabled),
                  ),
                ],
              ),
            ),
            Center(child: StatusLine(project: project)),
            const SizedBox(height: EcSpace.s2),
            SizedBox(
              height: 214,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: EcSpace.s3),
                child: const MonitorView(),
              ),
            ),
            const WarnBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(EcSpace.s4, EcSpace.s2, EcSpace.s4, 0),
              child: const ScrubBar(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(EcSpace.s4, EcSpace.s1, EcSpace.s4, 0),
              child: const TransportBar(),
            ),
            const SizedBox(height: EcSpace.s2),
            const Expanded(child: BlockList()),
            if (!ui.selectMode) const BottomActionBar(),
          ],
        ),
      ),
    );
  }
}
