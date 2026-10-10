import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/layout/layout_class.dart';
import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_chip.dart';
import '../../../core/widgets/ec_logo.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../../domain/models/block_catalog.dart';
import '../../../domain/models/credit_block.dart';
import '../../access/controllers/web_access.dart';
import '../../library/controllers/library_controller.dart';
import '../../blocks/screens/add_block_sheet.dart';
import '../../blocks/widgets/block_inspector.dart';
import '../../export/screens/export_sheet.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../monitor/widgets/monitor_view.dart';
import '../../paste/screens/paste_sheet.dart';
import '../../project/controllers/project_controller.dart';
import '../../settings/screens/settings_screen.dart';
import '../../timing/screens/timing_sheet.dart';
import '../controllers/editor_ui_controller.dart';
import '../widgets/block_list.dart';
import '../widgets/editor_dock.dart';
import '../widgets/landscape_monitor.dart';
import '../widgets/read_only_banner.dart';
import '../widgets/readability_banner.dart';
import '../widgets/scrub_bar.dart';
import '../widgets/status_line.dart';
import '../widgets/transport_bar.dart';

/// T3.1 / D11 — the editor on a tablet or a desktop browser. Nothing opens
/// as a sheet: the monitor, the block list and the selected block's
/// settings are on screen together.
///
/// Tablet: monitor, transport and the block panel on the left, the list on
/// the right. Desktop: three panes — blocks, the monitor over a time-true
/// timeline, and the selected block's settings.
///
/// Built from the phone editor's own pieces and providers, so resizing the
/// window between layouts keeps the selection, undo history and playback.
class WideEditor extends ConsumerWidget {
  const WideEditor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = context.layoutClass == LayoutClass.expanded;
    return _EditorShortcuts(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: EcGround(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                desktop ? const _DesktopBar() : const _TabletBar(),
                Expanded(child: desktop ? const _DesktopPanes() : const _TabletPanes()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Space plays, ← → step a frame, ⌘Z / ⇧⌘Z undo and redo, Esc clears the
/// selection — never while a text field has the keyboard.
class _EditorShortcuts extends ConsumerWidget {
  final Widget child;
  const _EditorShortcuts({required this.child});

  static bool get _typing {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    return focused.widget is EditableText || focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.read(playbackControllerProvider.notifier);
    final project = ref.read(projectControllerProvider.notifier);
    VoidCallback guard(VoidCallback action) => () {
      if (!_typing) action();
    };
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): guard(playback.togglePlay),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): guard(playback.stepBack),
        const SingleActivator(LogicalKeyboardKey.arrowRight): guard(playback.stepForward),
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): guard(project.undo),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): guard(project.undo),
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): guard(project.redo),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): guard(project.redo),
        const SingleActivator(LogicalKeyboardKey.escape): guard(() {
          final ui = ref.read(editorUiControllerProvider.notifier);
          if (ref.read(editorUiControllerProvider).selectMode) {
            ui.exitSelectMode();
          } else {
            ui.focus(null);
          }
        }),
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}

// ---------- bars ----------

class _TabletBar extends ConsumerWidget {
  const _TabletBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final project = ref.watch(projectControllerProvider);
    final selectMode = ref.watch(editorUiControllerProvider.select((s) => s.selectMode));
    if (selectMode) return const _SelectBar(height: 76);
    return SizedBox(
      height: 76,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Row(
          children: [
            _BackPill(onTap: () => Navigator.of(context).maybePop()),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(caps(_reelLabel(ref)), style: t.eyebrow.copyWith(fontSize: 9.5)),
                  const SizedBox(height: 3),
                  Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.displayS.copyWith(fontSize: 24, height: 1),
                  ),
                ],
              ),
            ),
            const _BarActions(compact: false),
          ],
        ),
      ),
    );
  }
}

class _DesktopBar extends ConsumerWidget {
  const _DesktopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final project = ref.watch(projectControllerProvider);
    final selectMode = ref.watch(editorUiControllerProvider.select((s) => s.selectMode));
    final preview = ref.watch(webPreviewProvider);
    if (selectMode) return const _SelectBar(height: 52);
    return Container(
      height: 52,
      padding: const EdgeInsets.fromLTRB(18, 0, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .4),
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const EcLogo(size: 12),
                const SizedBox(width: 18),
                Container(width: 1, height: 20, color: p.line2),
                const SizedBox(width: 18),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    foregroundColor: p.muted,
                    minimumSize: const Size(44, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(
                    'Projects',
                    style: t.bodyS.copyWith(fontSize: 13, color: p.muted, fontWeight: FontWeight.w500),
                  ),
                ),
                Text('›', style: t.bodyS.copyWith(color: p.faint)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.displayS.copyWith(fontSize: 21, height: 1),
                  ),
                ),
                const SizedBox(width: 10),
                _OutlinePill(preview ? 'Preview · read-only' : _reelLabel(ref), accent: preview),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const _BarActions(compact: true),
        ],
      ),
    );
  }
}

String _reelLabel(WidgetRef ref) {
  final project = ref.watch(projectControllerProvider);
  final reel = ref
      .watch(libraryViewProvider)
      .value
      ?.items
      .where((i) => i.summary.id == project.project.id)
      .firstOrNull
      ?.reel;
  return [
    if (reel != null) 'Reel ${reel.toString().padLeft(2, '0')}',
    project.settings.format.aspect,
    formatFps(project.settings.fps),
  ].join(' · ');
}

/// Undo, redo, Timing (showing the runtime), Export and the account.
class _BarActions extends ConsumerWidget {
  final bool compact;
  const _BarActions({required this.compact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final project = ref.watch(projectControllerProvider);
    final controller = ref.read(projectControllerProvider.notifier);
    final user = ref.watch(authStateProvider).value;
    final preview = ref.watch(webPreviewProvider);
    final healthy = rollHealth(project) == RollHealth.clean;
    final size = compact ? 34.0 : 40.0;
    final pill = compact ? 36.0 : 44.0;

    Widget history(IconData icon, String tooltip, VoidCallback? onPressed) => onPressed == null
        ? Tooltip(
            message: tooltip,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: 18, color: p.faint),
            ),
          )
        : EcCircleButton.glass(icon: icon, tooltip: tooltip, size: size, onPressed: onPressed);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        history(Icons.undo_rounded, 'Undo', controller.canUndo ? controller.undo : null),
        const SizedBox(width: 8),
        history(Icons.redo_rounded, 'Redo', controller.canRedo ? controller.redo : null),
        Container(
          width: 1,
          height: compact ? 20 : 24,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: p.line2,
        ),
        _GlassPill(
          height: pill,
          onTap: () => TimingSheet.show(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (preview) ...[Icon(Icons.lock_outline_rounded, size: 14, color: p.muted), const SizedBox(width: 6)],
              Text(
                formatClock(project.runtime.inMilliseconds / 1000),
                style: t.mono.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: healthy ? p.ink : p.warn),
              ),
              const SizedBox(width: 8),
              Text('Timing', style: t.buttonSmall.copyWith(fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: pill,
          child: EcButton(
            label: 'Export',
            size: compact ? EcButtonSize.small : EcButtonSize.medium,
            expand: false,
            leading: preview ? Icon(Icons.lock_outline_rounded, size: 14, color: p.onInk) : null,
            onPressed: () => ExportSheet.show(context),
          ),
        ),
        if (user != null) ...[
          const SizedBox(width: 8),
          EcAvatar(
            initials: user.initials,
            size: pill,
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
          ),
        ],
      ],
    );
  }
}

/// Select mode's bar (T3.2): Done, the count, and how much of the roll the
/// selection is.
class _SelectBar extends ConsumerWidget {
  final double height;
  const _SelectBar({required this.height});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final project = ref.watch(projectControllerProvider);
    final ids = ref.watch(editorUiControllerProvider.select((s) => s.selectedIds));
    final seconds = ids.fold<double>(0, (sum, id) => sum + (project.blockSeconds[id] ?? 0));
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            EcButton.secondary(
              label: 'Done',
              size: EcButtonSize.small,
              expand: false,
              onPressed: ref.read(editorUiControllerProvider.notifier).exitSelectMode,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '${plural(ids.length, 'block')} selected',
                style: t.displayS.copyWith(fontSize: 24, height: 1),
              ),
            ),
            Text(
              '${formatClock(seconds)} of ${formatClock(project.runtime.inMilliseconds / 1000)}',
              style: t.mono.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackPill extends StatelessWidget {
  final VoidCallback onTap;
  const _BackPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _GlassPill(
      height: 40,
      onTap: onTap,
      padding: const EdgeInsets.only(left: 10, right: 14),
      semanticLabel: 'Back to projects',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chevron_left_rounded, size: 20, color: p.ink2),
          const SizedBox(width: 2),
          Text('Projects', style: context.type.buttonSmall.copyWith(fontSize: 13, color: p.ink2)),
        ],
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final double height;
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  const _GlassPill({
    required this.height,
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: p.glass,
        shape: StadiumBorder(side: BorderSide(color: p.glassEdge)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: padding,
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinePill extends StatelessWidget {
  final String label;
  final bool accent;
  const _OutlinePill(this.label, {this.accent = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = accent ? p.accent : p.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent ? p.accentWash : null,
        border: Border.all(color: accent ? p.accentLine : p.line2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (accent) ...[Icon(Icons.visibility_outlined, size: 12, color: color), const SizedBox(width: 5)],
          Text(caps(label), style: context.type.pill.copyWith(fontSize: 9.5, letterSpacing: 1.1, color: color)),
        ],
      ),
    );
  }
}

// ---------- panes ----------

class _TabletPanes extends ConsumerWidget {
  const _TabletPanes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: (constraints.maxHeight * .44).clamp(200, 360), child: const _MonitorCard()),
                  const SizedBox(height: 12),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: ScrubBar()),
                  const _TransportRow(),
                  const SizedBox(height: 8),
                  const Expanded(child: _Panel(child: _InspectorOrNotices())),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          const SizedBox(width: 372, child: _Panel(child: _ListPane(actionsOnTop: false))),
        ],
      ),
    );
  }
}

class _DesktopPanes extends ConsumerWidget {
  const _DesktopPanes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 264,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .28),
            border: Border(right: BorderSide(color: p.line)),
          ),
          child: const _ListPane(actionsOnTop: true),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(child: _MonitorCard()),
                  const SizedBox(height: 10),
                  const _DesktopTransport(),
                  const SizedBox(height: 10),
                  const _Timeline(),
                  const SizedBox(height: 10),
                  const _HealthRow(),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 328,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .28),
            border: Border(left: BorderSide(color: p.line)),
          ),
          child: const _InspectorOrNotices(),
        ),
      ],
    );
  }
}

/// A white card the tablet's panels sit on.
class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(p.surface.withValues(alpha: .78), p.ground),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.glassEdge),
        boxShadow: p.glassShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// The monitor: black in every theme, with the roll's health as a chip.
class _MonitorCard extends ConsumerWidget {
  const _MonitorCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final project = ref.watch(projectControllerProvider);
    final e = project.engine;
    final healthy = rollHealth(project) == RollHealth.clean;
    final desktop = context.layoutClass == LayoutClass.expanded;
    final status = [
      formatFps(project.settings.fps),
      '${formatPpf(e.ppf)} px/frame',
      healthy ? 'clean' : (e.judderRisk ? 'judder risk' : 'too fast'),
      if (desktop) '${formatClock(project.runtime.inMilliseconds / 1000)} total',
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x990C6EC8), offset: Offset(0, 30), blurRadius: 60, spreadRadius: -34),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const MonitorView(),
          Positioned(
            right: 12,
            top: 10,
            child: _MonitorChipButton(
              icon: Icons.open_in_full_rounded,
              tooltip: 'Full screen',
              onPressed: () => _openFullScreen(context),
            ),
          ),
          if (desktop)
            Positioned(
              left: 18,
              right: 18,
              bottom: 12,
              child: IgnorePointer(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        caps(
                          'Canvas ${project.formatW} × ${project.formatH} · '
                          '${project.settings.format.aspect}',
                        ),
                        style: t.mono.copyWith(
                          fontSize: 9.5,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: .5),
                        ),
                      ),
                    ),
                    Text(
                      caps('Space play · ← → frame'),
                      style: t.mono.copyWith(
                        fontSize: 9.5,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: .5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 14,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                border: Border.all(color: Colors.white.withValues(alpha: .2)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: healthy ? p.okOnBlack : p.warnOnBlack, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(status, style: t.mono.copyWith(fontSize: 10, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The phone's landscape review monitor (3.4), full screen over the
/// editor; Esc or its close button comes back. Playback carries on across.
void _openFullScreen(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop()},
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: LandscapeMonitor(onExit: () => Navigator.of(context).maybePop()),
          ),
        ),
      ),
    ),
  );
}

class _MonitorChipButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _MonitorChipButton({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: .14),
        shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: .2))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(dimension: 32, child: Icon(icon, size: 15, color: Colors.white)),
        ),
      ),
    );
  }
}

/// The phone's transport, plus the selected block's range in words.
class _TransportRow extends ConsumerWidget {
  const _TransportRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) => const TransportBar();
}

class _DesktopTransport extends ConsumerWidget {
  const _DesktopTransport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final e = ref.watch(projectControllerProvider.select((s) => s.engine));
    final frame = ref.watch(playbackControllerProvider.select((s) => s.frame));
    return Row(
      children: [
        SizedBox(
          width: 330,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: formatTimecode(frame, e.fps), style: t.timecode.copyWith(fontSize: 26)),
                TextSpan(
                  text: '  / ${formatTimecode(e.totalFrames, e.fps)}',
                  style: t.mono.copyWith(fontSize: 11, color: p.muted),
                ),
              ],
            ),
          ),
        ),
        const Expanded(child: TransportBar()),
      ],
    );
  }
}

/// Blocks or, when none is selected, nothing to edit — with the roll's
/// warnings above it so a problem is never off screen.
class _InspectorOrNotices extends ConsumerWidget {
  const _InspectorOrNotices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On the desktop the bar's "Preview · read-only" pill already says it.
    final previewOnDesktop = ref.watch(webPreviewProvider) && context.layoutClass == LayoutClass.expanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!previewOnDesktop) const ReadOnlyBanner(),
        const ReadabilityBanner(),
        Expanded(
          child: BlockInspector(
            fastEntry: context.layoutClass == LayoutClass.expanded,
            castColumns: context.layoutClass == LayoutClass.medium ? 2 : 1,
          ),
        ),
      ],
    );
  }
}

/// The block list with + Block and Paste — at its foot on a tablet, at its
/// head on the desktop — and the select-mode actions in their place.
class _ListPane extends ConsumerWidget {
  final bool actionsOnTop;
  const _ListPane({required this.actionsOnTop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final selectMode = ref.watch(editorUiControllerProvider.select((s) => s.selectMode));
    // The web preview (D8) shows the list alone: nothing in it can change.
    final preview = ref.watch(webPreviewProvider);
    final editable = !ref.watch(editorReadOnlyProvider) || preview;
    final actions = Padding(
      padding: actionsOnTop ? const EdgeInsets.fromLTRB(12, 0, 12, 12) : const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: EcButton(
              label: 'Block',
              variant: EcButtonVariant.ink,
              size: actionsOnTop ? EcButtonSize.small : EcButtonSize.medium,
              expand: true,
              leading: Icon(Icons.add_rounded, size: 16, color: p.onInk),
              onPressed: editable ? () => AddBlockSheet.show(context) : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: EcButton.secondary(
              label: 'Paste',
              size: actionsOnTop ? EcButtonSize.small : EcButtonSize.medium,
              expand: true,
              leading: Icon(Icons.keyboard_tab_rounded, size: 15, color: p.ink),
              onPressed: editable ? () => PasteSheet.show(context) : null,
            ),
          ),
        ],
      ),
    );
    if (actionsOnTop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Expanded(child: BlockList(bottomInset: 16, belowHeader: selectMode || preview ? null : actions)),
          if (selectMode) const Padding(padding: EdgeInsets.all(10), child: BulkBar()),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        const Expanded(child: BlockList(bottomInset: 16)),
        if (selectMode) const Padding(padding: EdgeInsets.all(10), child: BulkBar()) else if (!preview) actions,
      ],
    );
  }
}

// ---------- desktop timeline ----------

/// D11: every block drawn at its real length, the selected one named, the
/// playhead over them. Fit, 2× and 4× zoom; tap a block to select it.
class _Timeline extends ConsumerStatefulWidget {
  const _Timeline();

  @override
  ConsumerState<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends ConsumerState<_Timeline> {
  int _zoom = 1;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final project = ref.watch(projectControllerProvider);
    final e = project.engine;
    final frame = ref.watch(playbackControllerProvider.select((s) => s.frame));
    final focusedId = ref.watch(editorUiControllerProvider.select((s) => s.focusedId));
    final total = e.totalFrames == 0 ? 1.0 : e.totalFrames / e.fps;
    // Each block from the moment it reaches the screen to the next one's —
    // the same marks as the scrub bar, so the playhead, the ticks and the
    // blocks agree; the head and tail black stay empty at either end.
    final starts = <(CreditBlock, double)>[
      for (final b in project.activeBlocks)
        if (b is! SpacerBlock && project.measurements.blockY[b.id] != null)
          (b, frameForY(e, project.measurements.blockY[b.id]! + (b is HoldBlock ? project.geometry.h : 0)) / e.fps),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final rollEnd = (e.totalFrames - e.tailFrames) / e.fps;
    final spans = [
      for (final (i, (b, start)) in starts.indexed) (b, start, i + 1 < starts.length ? starts[i + 1].$2 : rollEnd),
    ];
    final focused = spans.where((s) => s.$1.id == focusedId).firstOrNull;
    String range((CreditBlock, double, double) span) => '${formatClock(span.$2)} → ${formatClock(span.$3)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        // Glass flattened onto the ground, so the shadow can't show through.
        color: Color.alphaBlend(p.glass, p.ground),
        border: Border.all(color: p.glassEdge),
        borderRadius: BorderRadius.circular(18),
        boxShadow: p.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('TIMELINE', style: t.eyebrow.copyWith(fontSize: 10)),
              const SizedBox(width: 12),
              if (focused != null)
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${describeBlock(focused.$1).title} · '),
                        TextSpan(text: range(focused), style: t.mono.copyWith(fontSize: 11)),
                      ],
                    ),
                    style: t.bodyS.copyWith(fontSize: 12, color: p.ink2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              SizedBox(
                width: 150,
                child: EcSegmented(
                  labels: const ['Fit', '2×', '4×'],
                  selectedIndex: _zoom == 1 ? 0 : (_zoom == 2 ? 1 : 2),
                  onChanged: (i) => setState(() => _zoom = const [1, 2, 4][i]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth * _zoom;
              final pxPerSecond = width / total;
              final playheadX = (frame / e.fps) * pxPerSecond;
              final tickEvery = total <= 60 ? 10 : (total <= 240 ? 30 : 60);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  height: 86,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => ref
                        .read(playbackControllerProvider.notifier)
                        .scrubToFraction((d.localPosition.dx / width).clamp(0.0, 1.0)),
                    child: Stack(
                      children: [
                        for (var s = 0; s < total; s += tickEvery)
                          Positioned(
                            left: s * pxPerSecond,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                border: s == 0 ? null : Border(left: BorderSide(color: p.line2)),
                              ),
                              child: Text(formatClock(s.toDouble()), style: t.mono.copyWith(fontSize: 9.5)),
                            ),
                          ),
                        for (final (b, start, end) in spans)
                          Positioned(
                            left: start * pxPerSecond,
                            width: ((end - start) * pxPerSecond - 2).clamp(4.0, width),
                            top: 22,
                            height: 64,
                            child: _TimelineBlock(
                              code: b.kind.code,
                              title: describeBlock(b).title,
                              seconds: project.blockSeconds[b.id] ?? 0,
                              selected: b.id == focusedId,
                              onTap: () {
                                ref.read(editorUiControllerProvider.notifier).focus(b.id);
                                ref.read(playbackControllerProvider.notifier).seekToBlock(b.id);
                              },
                            ),
                          ),
                        Positioned(
                          left: playheadX.clamp(0, width - 2),
                          top: 16,
                          bottom: 0,
                          child: IgnorePointer(child: Container(width: 2, color: p.accentSolid)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TimelineBlock extends StatelessWidget {
  final String code;
  final String title;
  final double seconds;
  final bool selected;
  final VoidCallback onTap;

  const _TimelineBlock({
    required this.code,
    required this.title,
    required this.seconds,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Tooltip(
      message: '$code · $title · ${formatClock(seconds)}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? p.accentWash : Colors.white.withValues(alpha: .85),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: selected ? p.accentSolid : p.line, width: selected ? 1.5 : 1),
          ),
          child: LayoutBuilder(
            builder: (context, c) => c.maxWidth < 56
                ? const SizedBox.expand()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$code · ${formatClock(seconds)}',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: t.mono.copyWith(fontSize: 9.5, color: selected ? p.accent : p.muted),
                      ),
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleS.copyWith(fontSize: 12)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// D11's foot: judder, readability and the nearest clean runtimes, each a
/// chip — the same verdicts as the Timing panel.
class _HealthRow extends ConsumerWidget {
  const _HealthRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final project = ref.watch(projectControllerProvider);
    final e = project.engine;
    final neighbours = neighbourRates(e);
    final editable = !ref.watch(editorReadOnlyProvider);

    Widget verdict(bool ok, String title, String detail) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: ok ? p.okWash : p.warnWash, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ok ? Icons.check_rounded : Icons.error_outline_rounded, size: 15, color: ok ? p.ok : p.warn),
                const SizedBox(width: 4),
                Text(title, style: t.titleS.copyWith(fontSize: 13, color: ok ? p.ok : p.warn)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.mono.copyWith(fontSize: 10, color: p.ink2),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        verdict(!e.judderRisk, e.judderRisk ? 'Judder risk' : 'No judder', '${formatPpf(e.ppf)} px/frame'),
        const SizedBox(width: 10),
        verdict(
          e.readable,
          e.readable ? 'Readable' : 'Too fast',
          '${e.dwellSeconds.toStringAsFixed(1)}s dwell · floor 3.0s',
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border.all(color: p.line),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(child: Text('Nearest clean runtimes', style: t.bodyS.copyWith(fontSize: 12))),
                for (final rate in [neighbours.shorter, neighbours.longer])
                  if (rate != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ActionChip(
                        label: Text(
                          formatClock(rate.$2 / e.fps),
                          style: t.mono.copyWith(fontSize: 11, color: p.accent),
                        ),
                        backgroundColor: p.accentWash,
                        side: BorderSide(color: p.accentLine),
                        shape: const StadiumBorder(),
                        visualDensity: VisualDensity.compact,
                        onPressed: editable
                            ? () => ref.read(projectControllerProvider.notifier).applySnap(rate.$1)
                            : null,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
