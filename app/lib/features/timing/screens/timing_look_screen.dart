import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/layout_class.dart';
import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_chip.dart';
import '../../../core/widgets/ec_logo.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../domain/models/credit_block.dart';
import '../../export/screens/export_sheet.dart';
import '../../monitor/widgets/monitor_view.dart';
import '../../project/controllers/project_controller.dart';
import 'background_sheet.dart';
import 'look_sheet.dart';
import 'timing_sheet.dart';
import '../../ads/data/ad_service.dart';
import '../../ads/widgets/edge_ad_slot.dart';
import '../../home/tablet_layout.dart';

enum TimingLookTab { timing, look }

/// T5.1 / T5.2 / D13 — Timing and Look beside a monitor that updates live,
/// on a tablet or a desktop browser. The phone's three sheets (5.1–5.3),
/// drawn from the same panels.
///
/// Tablet: one panel at a time, switched by a Timing | Look control; the
/// dwell chart sits under the monitor on Timing. Desktop: Timing and Look
/// as two columns, the chart always shown.
class TimingLookScreen extends ConsumerStatefulWidget {
  final TimingLookTab tab;
  const TimingLookScreen({super.key, this.tab = TimingLookTab.timing});

  static Future<void> open(BuildContext context, TimingLookTab tab) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TimingLookScreen(tab: tab)));

  @override
  ConsumerState<TimingLookScreen> createState() => _TimingLookScreenState();
}

class _TimingLookScreenState extends ConsumerState<TimingLookScreen> {
  late TimingLookTab _tab = widget.tab;

  @override
  Widget build(BuildContext context) {
    final desktop = context.isDesktopLayout;
    // This route can remain open while a foldable switches to its cover
    // display. Its tablet columns must collapse with the available width.
    final portrait = context.tabletLayout == TabletLayout.portrait || context.layoutClass == LayoutClass.compact;
    void onTab(TimingLookTab t) => setState(() => _tab = t);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: EcGround(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              desktop
                  ? const _DesktopBar()
                  : portrait
                  ? _PortraitBar(tab: _tab, onTab: onTab)
                  : _TabletBar(tab: _tab, onTab: onTab),
              Expanded(
                child: desktop
                    ? const _DesktopBody()
                    : portrait
                    ? _PortraitBody(tab: _tab)
                    : _TabletBody(tab: _tab),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabletBar extends StatelessWidget {
  final TimingLookTab tab;
  final ValueChanged<TimingLookTab> onTab;
  const _TabletBar({required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return SizedBox(
      height: 76,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Row(
          children: [
            _EditorPill(onTap: () => Navigator.of(context).maybePop()),
            const SizedBox(width: 14),
            Semantics(
              header: true,
              child: Text(tab == TimingLookTab.timing ? 'Timing' : 'Look', style: t.displayM.copyWith(fontSize: 28)),
            ),
            const Spacer(),
            SizedBox(
              width: 190,
              child: EcSegmented(
                labels: const ['Timing', 'Look'],
                selectedIndex: tab.index,
                onChanged: (i) => onTab(TimingLookTab.values[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// P5.1: Editor, the Timing | Look switch in the middle, and Done.
class _PortraitBar extends StatelessWidget {
  final TimingLookTab tab;
  final ValueChanged<TimingLookTab> onTab;
  const _PortraitBar({required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width - MediaQuery.paddingOf(context).horizontal < 600) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _EditorPill(onTap: () => Navigator.of(context).maybePop()),
                EcButton(
                  label: 'Done',
                  variant: EcButtonVariant.ink,
                  size: EcButtonSize.medium,
                  height: 46,
                  expand: false,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              label: tab == TimingLookTab.timing ? 'Timing' : 'Look',
              child: EcSegmented(
                labels: const ['Timing', 'Look'],
                selectedIndex: tab.index,
                onChanged: (i) => onTab(TimingLookTab.values[i]),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 84,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _EditorPill(onTap: () => Navigator.of(context).maybePop()),
              ),
            ),
            SizedBox(
              width: 258,
              child: Semantics(
                header: true,
                label: tab == TimingLookTab.timing ? 'Timing' : 'Look',
                child: EcSegmented(
                  labels: const ['Timing', 'Look'],
                  selectedIndex: tab.index,
                  onChanged: (i) => onTab(TimingLookTab.values[i]),
                ),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: EcButton(
                  label: 'Done',
                  variant: EcButtonVariant.ink,
                  size: EcButtonSize.medium,
                  height: 46,
                  expand: false,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// P5.1 / P5.2: the monitor across the top, then Timing — the controls and
/// the dwell chart at full width — or Look.
class _PortraitBody extends StatelessWidget {
  final TimingLookTab tab;
  const _PortraitBody({required this.tab});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget card(Widget child) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: p.line),
      ),
      child: child,
    );
    final body = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 300, child: _Monitor()),
          const SizedBox(height: 14),
          if (tab == TimingLookTab.timing) ...[
            card(const TimingControls()),
            const SizedBox(height: 14),
            const SizedBox(height: 236, child: DwellChart()),
          ] else
            card(
              const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LookControls(),
                  SizedBox(height: 18),
                  BackgroundControls(),
                  SizedBox(height: 14),
                  _GuidesNote(),
                ],
              ),
            ),
        ],
      ),
    );
    // P5.2: the spare space at the foot holds the ad, at the same bottom
    // edge as the editor's, on both tabs.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: body),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: EdgeAdSlot(AdPlacement.timingLook, column: false, gap: 0),
        ),
      ],
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
    return Container(
      height: 52,
      padding: const EdgeInsets.fromLTRB(18, 0, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .4),
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Row(
        children: [
          const EcLogo(size: 12),
          const SizedBox(width: 18),
          Container(width: 1, height: 20, color: p.line2),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.chevron_left_rounded, size: 18, color: p.muted),
            label: Text('Editor', style: t.bodyS.copyWith(fontSize: 13, color: p.muted)),
            style: TextButton.styleFrom(minimumSize: const Size(44, 36)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.displayS.copyWith(fontSize: 21),
            ),
          ),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: p.inkSurface, borderRadius: BorderRadius.circular(999)),
            child: Row(
              children: [
                Text(
                  formatClock(project.runtime.inMilliseconds / 1000),
                  style: t.mono.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: p.onInk),
                ),
                const SizedBox(width: 8),
                Text('Timing', style: t.buttonSmall.copyWith(fontSize: 13, color: p.onInk)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: EcButton(
              label: 'Export',
              size: EcButtonSize.small,
              expand: false,
              onPressed: () => ExportSheet.show(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorPill extends StatelessWidget {
  final VoidCallback onTap;
  const _EditorPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: 'Back to the editor',
      excludeSemantics: true,
      child: Material(
        color: p.glass,
        shape: StadiumBorder(side: BorderSide(color: p.glassEdge)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chevron_left_rounded, size: 20, color: p.ink2),
                  Text('Editor', style: context.type.buttonSmall.copyWith(fontSize: 13, color: p.ink2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabletBody extends StatelessWidget {
  final TimingLookTab tab;
  const _TabletBody({required this.tab});

  @override
  Widget build(BuildContext context) {
    final timing = tab == TimingLookTab.timing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: timing ? 5 : 1, child: const _Monitor()),
                if (timing) ...[const SizedBox(height: 12), const Expanded(flex: 6, child: DwellChart())],
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 372,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Panel(
                    child: timing
                        ? const TimingControls()
                        : const Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LookControls(),
                              SizedBox(height: 18),
                              BackgroundControls(),
                              SizedBox(height: 14),
                              _GuidesNote(),
                            ],
                          ),
                  ),
                ),
                // T5.2: under the panel on both tabs, where the editor has it.
                const EdgeAdSlot(AdPlacement.timingLook, column: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopBody extends StatelessWidget {
  const _DesktopBody();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    Widget column(String title, Widget child) => Container(
      width: 330,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .28),
        border: Border(left: BorderSide(color: p.line)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(title, style: t.displayM.copyWith(fontSize: 30))),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: _Monitor()),
                SizedBox(height: 12),
                Expanded(flex: 4, child: DwellChart()),
              ],
            ),
          ),
        ),
        column('Timing', const TimingControls()),
        column(
          'Look',
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [LookControls(), SizedBox(height: 18), BackgroundControls(), SizedBox(height: 14), _GuidesNote()],
          ),
        ),
      ],
    );
  }
}

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
      child: SingleChildScrollView(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _Monitor extends StatelessWidget {
  const _Monitor();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: const MonitorView(),
    );
  }
}

class _GuidesNote extends StatelessWidget {
  const _GuidesNote();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line2),
      ),
      child: Text('Guides draw on the monitor only. They never appear in a render.', style: context.type.caption),
    );
  }
}

/// Seconds each block's names stay on screen, against the 3-second floor —
/// so a too-fast block is obvious before it becomes a warning. A scrolling
/// block's names cross the frame in the roll's dwell time; a hold card
/// stays for its hold.
class DwellChart extends ConsumerWidget {
  const DwellChart({super.key});

  static const floor = 3.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final project = ref.watch(projectControllerProvider);
    final e = project.engine;
    final blocks = [
      for (final b in project.activeBlocks)
        if (b is! SpacerBlock) b,
    ];
    final dwell = {for (final b in blocks) b.id: b is HoldBlock ? b.hold : e.dwellSeconds};
    final top = math.max(5.0, dwell.values.fold<double>(0, math.max) * 1.1);
    final allAbove = dwell.values.every((d) => d >= floor);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(p.surface.withValues(alpha: .78), p.ground),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.glassEdge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  caps('Dwell per block · seconds each name is on screen'),
                  style: t.eyebrow.copyWith(fontSize: 9.5),
                ),
              ),
              Text(
                allAbove ? 'All above ${floor.toStringAsFixed(1)}s' : 'Some under ${floor.toStringAsFixed(1)}s',
                style: t.mono.copyWith(fontSize: 10.5, color: allAbove ? p.ok : p.warn),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: blocks.isEmpty
                ? Center(child: Text('No blocks yet.', style: t.caption))
                : LayoutBuilder(
                    builder: (context, c) {
                      final labelStyle = t.mono.copyWith(fontSize: 8.5);
                      final labels = [
                        for (final b in blocks)
                          TextPainter(
                            text: TextSpan(text: b.kind.code, style: labelStyle),
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                            maxLines: 1,
                          )..layout(),
                      ];
                      final labelHeight = labels.fold<double>(0, (height, label) => math.max(height, label.height));
                      final columnWidth = labels.fold<double>(28, (width, label) => math.max(width, label.width + 6));
                      for (final label in labels) {
                        label.dispose();
                      }
                      final chartH = math.max(0.0, c.maxHeight - labelHeight - 4);
                      final floorY = chartH * (1 - floor / top);
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: math.max(c.maxWidth, blocks.length * columnWidth),
                          height: c.maxHeight,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                right: 0,
                                top: floorY,
                                child: Container(height: 1, color: p.line2),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (final b in blocks)
                                    Expanded(
                                      child: Tooltip(
                                        message: '${b.kind.code} · ${dwell[b.id]!.toStringAsFixed(1)}s',
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 3),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Container(
                                                height: (chartH * (dwell[b.id]! / top)).clamp(0, chartH),
                                                decoration: BoxDecoration(
                                                  color: dwell[b.id]! >= floor ? p.okWash : p.warnWash,
                                                  border: Border.all(
                                                    color: dwell[b.id]! >= floor
                                                        ? p.ok.withValues(alpha: .35)
                                                        : p.warnLine,
                                                  ),
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(b.kind.code, style: labelStyle, maxLines: 1),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
