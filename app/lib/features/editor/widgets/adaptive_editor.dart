import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_tool_host.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../blocks/screens/add_block_sheet.dart';
import '../../export/screens/export_sheet.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../monitor/widgets/monitor_view.dart';
import '../../paste/screens/paste_sheet.dart';
import '../../project/controllers/project_controller.dart';
import '../../timing/screens/timing_sheet.dart';
import '../controllers/editor_ui_controller.dart';
import 'block_list.dart';
import 'editor_dock.dart';
import 'editor_timeline.dart';
import 'landscape_monitor.dart';
import 'read_only_banner.dart';
import 'scrub_bar.dart';
import 'status_line.dart';
import 'transport_bar.dart';

/// A stable route/session above the three presentation compositions.
class AdaptiveEditor extends ConsumerStatefulWidget {
  final Widget mobile;
  const AdaptiveEditor({super.key, required this.mobile});
  @override
  ConsumerState<AdaptiveEditor> createState() => _AdaptiveEditorState();
}

class _AdaptiveEditorState extends ConsumerState<AdaptiveEditor> {
  WidgetBuilder? _tool;
  Completer<Object?>? _result;
  GlobalKey _toolKey = GlobalKey();
  final _listKey = GlobalKey();
  final _ownerKey = GlobalKey();
  final _monitorKey = GlobalKey();
  final _timelineKey = GlobalKey();
  final _keyboard = FocusNode(debugLabel: 'Editor shortcuts');

  Future<Object?> _present(WidgetBuilder builder) {
    _result?.complete(null);
    final result = Completer<Object?>();
    setState(() {
      _result = result;
      _tool = builder;
      _toolKey = GlobalKey();
    });
    return result.future;
  }

  void _complete(Object? result) {
    final pending = _result;
    setState(() {
      _result = null;
      _tool = null;
    });
    pending?.complete(result);
  }

  @override
  void dispose() {
    _result?.complete(null);
    _keyboard.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || ModalRoute.of(context)?.isCurrent != true) {
      return KeyEventResult.ignored;
    }
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext?.findAncestorWidgetOfExactType<EditableText>() != null ||
        focusContext?.widget is EditableText) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final playback = ref.read(playbackControllerProvider.notifier);
    if (event.logicalKey == LogicalKeyboardKey.space) {
      playback.togglePlay();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      playback.stepBack();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      playback.stepForward();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Widget _panel() => LayoutBuilder(
    builder: (context, constraints) {
      final panel = EcPanelPresentation(
        complete: _complete,
        child: KeyedSubtree(
          key: _toolKey,
          child: _tool == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Select a block to edit',
                      style: context.type.bodyS,
                    ),
                  ),
                )
              : Builder(builder: _tool!),
        ),
      );
      if (constraints.maxHeight < 360) {
        return SingleChildScrollView(
          child: SizedBox(height: 360, child: panel),
        );
      }
      return panel;
    },
  );

  @override
  Widget build(BuildContext context) {
    // Keep auto-disposed UI and draft providers alive across layout changes.
    final ui = ref.watch(editorUiControllerProvider);
    final project = ref.watch(projectControllerProvider);
    return EcToolHost(
      present: _present,
      ownerKey: _ownerKey,
      enabled: MediaQuery.sizeOf(context).width >= 768,
      child: Builder(
        key: _ownerKey,
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) {
            final layout = layoutForWidth(constraints.maxWidth);
            final wide =
                layout == EcLayout.tablet || layout == EcLayout.desktop;
            final phoneReview =
                isNativePhone(context) &&
                MediaQuery.orientationOf(context) == Orientation.landscape;
            if (phoneReview) {
              return const Scaffold(
                backgroundColor: Colors.black,
                body: LandscapeMonitor(),
              );
            }
            final desktop = layout == EcLayout.desktop;
            if (!wide) {
              return Stack(
                children: [
                  if (!isNativePhone(context) && constraints.maxHeight < 640)
                    SingleChildScrollView(
                      child: SizedBox(height: 640, child: widget.mobile),
                    )
                  else
                    widget.mobile,
                  if (_tool != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                      child: ColoredBox(
                        color: context.palette.scrim,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            height: math.max(200, constraints.maxHeight * .9),
                            child: _panel(),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }
            return Builder(
              builder: (context) => Focus(
                focusNode: _keyboard,
                autofocus: true,
                onKeyEvent: _onKey,
                child: Scaffold(
                  backgroundColor: context.palette.ground,
                  body: EcGround(
                    child: SafeArea(
                      child: Column(
                        children: [
                          _toolbar(context, project),
                          const ReadOnlyBanner(),
                          if (ui.selectMode)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 6,
                              ),
                              child: BulkBar(),
                            ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                desktop ? 0 : 20,
                                4,
                                desktop ? 0 : 20,
                                desktop ? 0 : 20,
                              ),
                              child: desktop
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        SizedBox(
                                          width: 264,
                                          child: _blocks(context),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  _viewer(
                                                    context,
                                                    math.max(
                                                      180,
                                                      math.min(
                                                        420,
                                                        constraints.maxHeight *
                                                            .42,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  KeyedSubtree(
                                                    key: _timelineKey,
                                                    child:
                                                        const EditorTimeline(),
                                                  ),
                                                  const SizedBox(height: 14),
                                                  _timingReport(project),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 328,
                                          decoration: BoxDecoration(
                                            color: context.palette.sheet,
                                            border: Border(
                                              left: BorderSide(
                                                color: context.palette.line,
                                              ),
                                            ),
                                          ),
                                          child: _panel(),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: LayoutBuilder(
                                            builder: (context, pane) {
                                              final monitorHeight = math.max(
                                                160.0,
                                                math.min(
                                                  320.0,
                                                  constraints.maxHeight * .38,
                                                ),
                                              );
                                              return SingleChildScrollView(
                                                child: Column(
                                                  children: [
                                                    _viewer(
                                                      context,
                                                      monitorHeight,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    SizedBox(
                                                      height: math.max(
                                                        360.0,
                                                        pane.maxHeight -
                                                            monitorHeight -
                                                            180,
                                                      ),
                                                      child: _panel(),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        SizedBox(
                                          width: (constraints.maxWidth * .32)
                                              .clamp(280, 372),
                                          child: _blocks(context),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context, ProjectState project) {
    final controller = ref.read(projectControllerProvider.notifier);
    final editable = !ref.watch(editorReadOnlyProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Projects'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${project.settings.format.aspect} · ${formatFps(project.engine.fps)}',
                  style: context.type.mono.copyWith(fontSize: 10),
                ),
                Text(
                  project.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.barTitle,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Undo',
            onPressed: controller.canUndo && editable ? controller.undo : null,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: controller.canRedo && editable ? controller.redo : null,
            icon: const Icon(Icons.redo_rounded),
          ),
          TextButton(
            onPressed: editable ? () => TimingSheet.show(context) : null,
            child: const Text('Timing'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => ExportSheet.show(context),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Widget _blocks(BuildContext context) {
    final editable = !ref.watch(editorReadOnlyProvider);
    return Column(
      children: [
        Expanded(child: BlockList(key: _listKey, bottomInset: 16)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: editable ? () => AddBlockSheet.show(context) : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Block'),
              ),
              TextButton.icon(
                onPressed: editable ? () => PasteSheet.show(context) : null,
                icon: const Icon(Icons.keyboard_tab_rounded),
                label: const Text('Paste'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _viewer(BuildContext context, double height) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'SPACE PLAY · ← → FRAME',
                      style: context.type.mono.copyWith(
                        fontSize: 9,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fullscreen monitor',
                  color: Colors.white,
                  icon: const Icon(Icons.fullscreen_rounded),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => Scaffold(
                          backgroundColor: Colors.black,
                          body: LandscapeMonitor(
                            onExit: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            SizedBox(
              height: height,
              child: MonitorView(key: _monitorKey),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: StatusLine(
                project: ref.watch(projectControllerProvider),
                onBlack: true,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const ScrubBar(),
      const TransportBar(),
    ],
  );

  Widget _timingReport(ProjectState project) {
    final e = project.engine;
    final neighbours = neighbourRates(e);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        Text(
          '${e.judderRisk ? 'Judder risk' : 'Steady pace'} · ${e.ppf.toStringAsFixed(2)} px/frame',
          style: context.type.bodyS,
        ),
        Text(
          '${e.readable ? 'Readable' : 'Too fast'} · ${e.dwellSeconds.toStringAsFixed(1)}s dwell',
          style: context.type.bodyS,
        ),
        if (neighbours.shorter != null || neighbours.longer != null)
          Text('Steady runtimes:', style: context.type.bodyS),
        for (final rate in [neighbours.shorter, neighbours.longer])
          if (rate != null)
            TextButton(
              onPressed: ref.watch(editorReadOnlyProvider)
                  ? null
                  : () {
                      ref
                          .read(projectControllerProvider.notifier)
                          .applySnap(rate.$1);
                      ref.read(editorUiControllerProvider.notifier).resetWarn();
                    },
              child: Text(formatTimecode(rate.$2, e.fps).substring(3, 8)),
            ),
      ],
    );
  }
}
