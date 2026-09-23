import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/orientations.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../monitor/widgets/monitor_view.dart';
import '../../project/controllers/project_controller.dart';
import '../controllers/editor_ui_controller.dart';
import '../widgets/block_list.dart';
import '../widgets/editor_dock.dart';
import '../widgets/landscape_monitor.dart';
import '../widgets/readability_banner.dart';
import '../widgets/scrub_bar.dart';
import '../widgets/status_line.dart';
import '../widgets/transport_bar.dart';

/// 3.1 — the hub. Monitor on top, blocks below, four actions in a dock.
/// Turning the phone opens the review monitor (3.4).
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  /// Held rather than read through `ref` in [dispose], where the widget's
  /// ref is no longer usable. The controller itself outlives this screen.
  late final ProjectController _project;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _project = ref.read(projectControllerProvider.notifier);
    SystemChrome.setPreferredOrientations(kEditorOrientations);

    // A debounced autosave is a lost edit if the app is backgrounded mid
    // debounce, so a pause flushes whatever is pending immediately.
    _lifecycle = AppLifecycleListener(
      onPause: () => _project.flushPendingSave(),
      onDetach: () => _project.flushPendingSave(),
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    SystemChrome.setPreferredOrientations(kPortraitOnly);
    super.dispose();
  }

  /// Clean close: writes the document and clears the left-open flag so the
  /// next launch offers a plain resume rather than a crash recovery.
  ///
  /// Driven by the pop rather than [dispose]: Riverpod forbids modifying a
  /// provider during a widget lifecycle callback. If a pop path ever
  /// bypassed this, autosave has still persisted every edit — the only cost
  /// is being offered a recovery for a session that ended cleanly.
  void _handlePop(bool didPop) {
    if (didPop) _project.closeProject();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: OrientationBuilder(
        builder: (context, orientation) => orientation == Orientation.landscape
            ? const Scaffold(backgroundColor: Colors.black, body: LandscapeMonitor())
            : const _PortraitEditor(),
      ),
    );
  }
}

class _PortraitEditor extends ConsumerWidget {
  const _PortraitEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final project = ref.watch(projectControllerProvider);
    final controller = ref.read(projectControllerProvider.notifier);
    final selectMode = ref.watch(editorUiControllerProvider.select((s) => s.selectMode));

    return Scaffold(
      backgroundColor: p.ground,
      body: EcGround(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          EcCircleButton.glass(
                            icon: Icons.chevron_left_rounded,
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              project.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.barTitle.copyWith(fontSize: 21),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _HistoryButton(icon: Icons.undo_rounded, tooltip: 'Undo', onPressed: controller.canUndo ? controller.undo : null),
                          const SizedBox(width: 4),
                          _HistoryButton(icon: Icons.redo_rounded, tooltip: 'Redo', onPressed: controller.canRedo ? controller.redo : null),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 220, child: ColoredBox(color: Colors.black, child: MonitorView())),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: StatusLine(project: project)),
                        const SizedBox(height: 8),
                        const ScrubBar(),
                        const TransportBar(),
                      ],
                    ),
                  ),
                  const ReadabilityBanner(),
                  const SizedBox(height: 6),
                  const Expanded(child: BlockList()),
                ],
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 18 + MediaQuery.paddingOf(context).bottom,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: selectMode ? const BulkBar(key: ValueKey('bulk')) : const EditorDock(key: ValueKey('dock')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Undo and redo: glass when there is something to step to, bare and faint
/// when there isn't.
class _HistoryButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _HistoryButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (onPressed != null) return EcCircleButton.glass(icon: icon, tooltip: tooltip, onPressed: onPressed);
    return Tooltip(
      message: tooltip,
      child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: context.palette.faint)),
    );
  }
}
