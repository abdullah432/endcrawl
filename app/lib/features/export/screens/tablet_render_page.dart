import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/config/app_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' show basename;

import '../../../core/result.dart';
import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/render_summary.dart';
import '../../ads/data/ad_service.dart';
import '../../ads/widgets/sponsored_slot.dart';
import '../../home/tablet_layout.dart';
import '../../library/controllers/library_controller.dart';
import '../../monitor/widgets/roll_frame.dart';
import '../../project/controllers/project_controller.dart';
import '../../review/review_prompt.dart';
import '../controllers/export_controller.dart';
import '../models/export_artifact.dart';
import '../models/export_models.dart';
import 'export_sheet.dart' show RenderProgressBar;

/// The tablet's render page (T6.2, P6.2): the frame being encoded on the
/// monitor, the progress card under it and, on Free, the one static ad in
/// the wait — gone when the render ends. Beside it in landscape (below in
/// portrait) is the Renders list: this render once it has finished or
/// failed, with its actions, then the last render of each other project.
///
/// One render runs at a time and only the latest file is kept, so earlier
/// renders are listed as what happened, without file actions.
class TabletRenderPage extends ConsumerWidget {
  final ExportRun run;
  const TabletRenderPage({super.key, required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final portrait = context.tabletLayout == TabletLayout.portrait;
    final running = run.phase == ExportPhase.running;

    final header = Row(
      children: [
        Expanded(
          child: Text(
            caps('Export · ${run.projectTitle}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.eyebrow.copyWith(fontSize: 10.5, letterSpacing: 10.5 * .14),
          ),
        ),
        EcCircleButton.tint(
          icon: Icons.close_rounded,
          size: 44,
          tooltip: 'Close',
          onPressed: () => closeEcSheet(context),
        ),
      ],
    );
    final status = _StatusCard(run: run, portrait: portrait);
    // The wait's ad only while the encoder runs; the rating question can
    // take its place, as on the phone. A failure is a problem, not a wait.
    final slot = switch (run.phase) {
      ExportPhase.running => RateSlot(
        ad: TabletAdSlot(AdPlacement.rendering, layout: AdLayout.strip, portrait: portrait, gap: 14),
      ),
      ExportPhase.done => const RateSlot(ad: SizedBox.shrink()),
      ExportPhase.failed => const SizedBox.shrink(),
    };
    final renders = _RendersPanel(run: run, portrait: portrait);

    if (portrait) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 12),
            AspectRatio(aspectRatio: 16 / 10, child: _RenderMonitor(run: run)),
            const SizedBox(height: 14),
            status,
            slot,
            const SizedBox(height: 14),
            renders,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 65,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final column = [status, slot];
                      // The monitor takes what the card and ad leave; with
                      // large text the column scrolls under a fixed one.
                      if (constraints.maxHeight >= (running ? 600 : 460)) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _RenderMonitor(run: run)),
                            const SizedBox(height: 14),
                            ...column,
                          ],
                        );
                      }
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 240, child: _RenderMonitor(run: run)),
                            const SizedBox(height: 14),
                            ...column,
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 35, child: renders),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The black monitor with the frame the encoder is on, labelled with what
/// the file will be.
class _RenderMonitor extends ConsumerStatefulWidget {
  final ExportRun run;
  const _RenderMonitor({required this.run});

  @override
  ConsumerState<_RenderMonitor> createState() => _RenderMonitorState();
}

class _RenderMonitorState extends ConsumerState<_RenderMonitor> {
  late final _frame = ValueNotifier<double>(_frameFor(widget.run));

  /// The encoder's frame on the roll's clock. A finished roll's last frame
  /// is usually empty, so a done render rests mid-roll instead.
  double _frameFor(ExportRun run) {
    final total = ref.read(projectControllerProvider).engine.totalFrames;
    if (run.phase == ExportPhase.done) return total / 2;
    if (run.totalFrames == 0) return 0;
    return (total * run.frame / run.totalFrames).clamp(0, math.max(0, total - 1)).toDouble();
  }

  @override
  void didUpdateWidget(_RenderMonitor old) {
    super.didUpdateWidget(old);
    _frame.value = _frameFor(widget.run);
  }

  @override
  void dispose() {
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final project = ref.watch(projectControllerProvider);
    final g = project.geometry;
    final run = widget.run;

    return ClipRRect(
      borderRadius: BorderRadius.circular(EcRadius.group),
      child: ColoredBox(
        color: p.monitor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final scale = math.min(constraints.maxWidth / g.w, constraints.maxHeight / g.h);
                return Center(
                  child: SizedBox(
                    width: g.w * scale,
                    height: g.h * scale,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: g.w,
                        maxWidth: g.w,
                        minHeight: g.h,
                        maxHeight: g.h,
                        child: Transform.scale(
                          alignment: Alignment.topLeft,
                          scale: scale,
                          child: RollFrame(
                            settings: project.settings,
                            blocks: project.activeBlocks,
                            geometry: g,
                            engine: project.engine,
                            frame: _frame,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              left: 16,
              top: 14,
              child: Text(
                '${run.codec.label} · ${run.width} × ${run.height}',
                style: t.mono.copyWith(fontSize: 10, color: Colors.white.withValues(alpha: .7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress while it runs; the outcome once it ends.
class _StatusCard extends ConsumerWidget {
  final ExportRun run;
  final bool portrait;
  const _StatusCard({required this.run, required this.portrait});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final controller = ref.read(exportControllerProvider.notifier);
    final pct = (run.progress * 100).floor();

    final (headline, figure, colour, left, right) = switch (run.phase) {
      ExportPhase.running => (
        'Rendering…',
        '$pct%',
        p.accent,
        'frame ${run.frame} / ${run.totalFrames}',
        run.frame == 0 ? 'Preparing…' : '${formatAbout(run.secondsLeft)} left',
      ),
      ExportPhase.done => (
        'Rendered.',
        '100%',
        p.ok,
        'frame ${run.totalFrames} / ${run.totalFrames}',
        formatBytes((run.fileBytes ?? 0).toDouble()),
      ),
      ExportPhase.failed => (
        'Stopped.',
        '$pct%',
        p.warn,
        'frame ${run.frame} / ${run.totalFrames}',
        'nothing was saved',
      ),
    };
    final actions = switch (run.phase) {
      ExportPhase.running => [
        Expanded(
          child: EcButton(
            label: 'Keep working · renders in background',
            variant: EcButtonVariant.ink,
            height: 52,
            onPressed: () => closeEcSheet(context),
          ),
        ),
        const SizedBox(width: 10),
        EcButton.secondary(label: 'Cancel', height: 52, expand: false, onPressed: controller.cancel),
      ],
      ExportPhase.done => [
        Expanded(
          child: EcButton(
            label: 'Done',
            variant: EcButtonVariant.ink,
            height: 52,
            onPressed: () => closeEcSheet(context),
          ),
        ),
        const SizedBox(width: 10),
        EcButton.secondary(label: 'New render', height: 52, expand: false, onPressed: controller.dismiss),
      ],
      ExportPhase.failed => [
        Expanded(
          child: EcButton.secondary(label: 'Back to settings', height: 52, onPressed: controller.dismiss),
        ),
      ],
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(EcRadius.group),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(headline, style: t.displayM.copyWith(fontSize: 32)),
                ),
              ),
              Text(figure, style: t.titleM.copyWith(fontSize: 22, fontWeight: FontWeight.w500, color: colour)),
            ],
          ),
          const SizedBox(height: 14),
          RenderProgressBar(run.phase == ExportPhase.done ? 1 : run.progress),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(left, style: t.mono.copyWith(fontSize: 11))),
              Text(right, style: t.mono.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 18),
          Row(children: actions),
        ],
      ),
    );
  }
}

/// "Renders": this render's outcome with what can be done about it, then
/// the last render of each other project.
class _RendersPanel extends ConsumerWidget {
  final ExportRun run;
  final bool portrait;
  const _RendersPanel({required this.run, required this.portrait});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final earlier = [
      for (final s in ref.watch(projectSummariesProvider).value ?? const [])
        if (s.id != run.projectId && s.lastRender != null) (s.title, s.lastRender!),
    ]..sort((a, b) => b.$2.at.compareTo(a.$2.at));

    final cards = <Widget>[
      if (run.phase == ExportPhase.done) _DoneCard(run: run, portrait: portrait),
      if (run.phase == ExportPhase.failed) _FailedCard(run: run, portrait: portrait),
      for (final (title, summary) in earlier.take(6)) _EarlierRow(title: title, summary: summary),
    ];

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('RENDERS', style: t.eyebrow.copyWith(fontSize: 10, letterSpacing: 10 * .14)),
        const SizedBox(height: 12),
        if (cards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Finished and failed renders land here.',
              style: t.body.copyWith(fontSize: 13, color: p.muted),
            ),
          ),
        for (final (i, card) in cards.indexed) ...[if (i > 0) const SizedBox(height: 12), card],
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: BorderRadius.circular(EcRadius.hero),
        border: Border.all(color: p.line),
      ),
      child: portrait ? list : SingleChildScrollView(child: list),
    );
  }
}

String _short(int width, int height) {
  final edge = math.min(width, height);
  return edge >= 2160 ? '4K' : '${edge}p';
}

class _DoneCard extends ConsumerWidget {
  final ExportRun run;
  final bool portrait;
  const _DoneCard({required this.run, required this.portrait});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final destinations = ref.read(exportDestinationsProvider);
    final path = run.outputPath!;
    final artifact =
        run.artifact ??
        ExportArtifact(location: path, filename: basename(path), mimeType: 'video/mp4', bytes: run.fileBytes ?? 0);

    Future<void> deliver(Future<Result<void>> action, {String? done}) async {
      final result = await action;
      if (!context.mounted) return;
      switch (result) {
        case Ok():
          if (done != null) showEcToast(context, done);
        case Err(:final failure):
          showEcToast(context, failure.message);
      }
    }

    Rect? origin() {
      final box = context.findRenderObject() as RenderBox?;
      return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    }

    // Saving keeps the file on this device: a video goes to Photos, an
    // image sequence (or the web's file) through Files or a download.
    void save() => deliver(
      (kIsWeb || AppPlatform.isNativeDesktop)
          ? destinations.download(artifact)
          : run.codec == Codec.png
          ? destinations.share(artifact, origin: origin())
          : destinations.saveToPhotos(artifact),
      done: AppPlatform.isMobile && run.codec != Codec.png ? 'Saved to Photos' : null,
    );
    final canShare = destinations.canShare(artifact);

    return _RenderCard(
      portrait: portrait,
      icon: Icon(Icons.check_rounded, size: 16, color: p.ok),
      iconFill: p.okWash,
      title: run.projectTitle,
      detail: [
        run.codec.label,
        _short(run.width, run.height),
        formatBytes((run.fileBytes ?? 0).toDouble()),
        'done',
      ].join(' · '),
      actions: [
        _Pill(label: portrait ? 'Save' : 'Save to device', fill: p.inkSurface, ink: p.onInk, onTap: save),
        if (canShare)
          _Pill(
            label: 'Share',
            fill: p.tint,
            ink: p.ink,
            onTap: () => deliver(destinations.share(artifact, origin: origin())),
          ),
      ],
    );
  }
}

class _FailedCard extends ConsumerWidget {
  final ExportRun run;
  final bool portrait;
  const _FailedCard({required this.run, required this.portrait});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final controller = ref.read(exportControllerProvider.notifier);
    final noSpace = run.failure == EncoderFailureKind.outOfSpace;
    final canLower = run.width > ExportResolution.hd.edge || run.height > ExportResolution.hd.edge;
    final body = noSpace
        ? kIsWeb
              ? '${run.failureMessage ?? 'Browser storage is full.'} Nothing in the project changed.'
              : 'Free up about ${formatBytes(run.neededBytes ?? run.bytes)}, then retry. Nothing in the project changed.'
        : '${run.failureMessage ?? 'The encoder stopped.'} Nothing in the project changed.';

    return _RenderCard(
      portrait: portrait,
      warn: true,
      icon: Icon(Icons.priority_high_rounded, size: 16, color: p.warn),
      iconFill: p.warnWash,
      title: run.projectTitle,
      detail: 'Stopped at frame ${run.frame} · ${noSpace ? 'not enough storage' : 'the encoder stopped'}',
      body: body,
      actions: [
        _Pill(
          label: portrait ? 'Retry' : 'Retry render',
          fill: p.warnWash,
          ink: p.warn,
          onTap: controller.retry,
        ),
        if (canLower)
          _Pill(
            label: portrait ? 'At 1920' : 'Retry at 1920',
            fill: p.tint,
            ink: p.ink,
            onTap: controller.retryAtLowerResolution,
          ),
      ],
    );
  }
}

/// Another project's last render: what happened and when.
class _EarlierRow extends StatelessWidget {
  final String title;
  final RenderSummary summary;
  const _EarlierRow({required this.title, required this.summary});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final failed = summary.outcome == RenderOutcome.failed;
    return _RenderCard(
      portrait: true,
      warn: failed,
      icon: failed
          ? Icon(Icons.priority_high_rounded, size: 16, color: p.warn)
          : Icon(Icons.check_rounded, size: 16, color: p.ok),
      iconFill: failed ? p.warnWash : p.okWash,
      title: title,
      detail: [
        summary.codec,
        _short(summary.width, summary.height),
        failed ? 'failed' : 'done',
        formatRelativeTime(summary.at),
      ].join(' · '),
      actions: const [],
    );
  }
}

/// One entry of the Renders list. Landscape stacks the actions under the
/// text; portrait keeps each entry to one row, actions at its end.
class _RenderCard extends StatelessWidget {
  final bool portrait;
  final bool warn;
  final Widget icon;
  final Color iconFill;
  final String title;
  final String detail;
  final String? body;
  final List<Widget> actions;

  const _RenderCard({
    required this.portrait,
    this.warn = false,
    required this.icon,
    required this.iconFill,
    required this.title,
    required this.detail,
    this.body,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final heading = Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: iconFill, shape: BoxShape.circle),
          child: icon,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleM.copyWith(fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                detail,
                style: t.mono.copyWith(fontSize: 10.5, color: warn ? p.warn : p.muted),
              ),
            ],
          ),
        ),
        if (portrait)
          for (final a in actions) ...[const SizedBox(width: 8), a],
      ],
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(EcRadius.card),
        border: Border.all(color: warn ? p.warnLine : p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          if (!portrait && body != null) ...[
            const SizedBox(height: 10),
            Text(body!, style: t.body.copyWith(fontSize: 13, color: p.ink2, height: 1.45)),
          ],
          if (!portrait && actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (final (i, a) in actions.indexed) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: a)],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color fill;
  final Color ink;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.fill, required this.ink, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Material(
      color: fill,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.buttonSmall.copyWith(color: ink, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
