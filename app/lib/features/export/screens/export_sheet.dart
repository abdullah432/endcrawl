import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/export_artifact.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' show basename;

import '../../../bootstrap.dart';
import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/result.dart';
import '../../../core/utils/formatting.dart';
import '../../ads/data/ad_service.dart';
import '../../ads/screens/rewarded_ad_screen.dart';
import '../../ads/widgets/sponsored_slot.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_chip.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_settings.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_tool_host.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../../domain/models/project_settings.dart';
import '../../plan/screens/pro_sheet.dart';
import '../../plan/controllers/release_policy.dart';
import '../../project/controllers/project_controller.dart';
import '../../review/data/feedback_repository.dart';
import '../../review/review_prompt.dart';
import '../../timing/screens/timing_sheet.dart';
import '../controllers/export_controller.dart';
import '../models/export_models.dart';
import '../../home/tablet_layout.dart';

final _exportPresentationProvider = Provider((ref) => _ExportPresentation());

class _ExportPresentation {
  bool open = false;
}

/// Export: settings (6.1), rendering (6.2), failed (6.3), ready (6.4).
///
/// Free and Pro render exactly the same file — every codec and resolution,
/// no watermark, no end card. Free accounts see one interstitial after a
/// render succeeds, and the existing native placements; Pro is ad-free.
class ExportSheet extends ConsumerWidget {
  const ExportSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final presentation = container.read(_exportPresentationProvider);
    if (presentation.open) return;
    presentation.open = true;
    try {
      if (context.isTablet) {
        // T6.1 / P6.1: the whole screen, every phase drawn on the page.
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (page) => Scaffold(
              backgroundColor: page.palette.sheet,
              body: SafeArea(
                child: EcPanelPresentation(
                  fullScreen: true,
                  complete: (_) => Navigator.of(page).maybePop(),
                  child: const ExportSheet(),
                ),
              ),
            ),
          ),
        );
      } else {
        await showEcSheet<void>(
          context,
          panel: true,
          builder: (_) => const ExportSheet(),
        );
      }
      // A delivered file is done with; a failure stays, to be resumed.
      if (context.mounted &&
          container.read(exportControllerProvider).run?.phase ==
              ExportPhase.done) {
        container.read(exportControllerProvider.notifier).dismiss();
      }
    } finally {
      presentation.open = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ref.watch(
      projectControllerProvider.select((s) => s.project.id),
    );
    final run = ref.watch(exportControllerProvider.select((s) => s.run));
    final mine = run != null && run.projectId == projectId;

    final rate = ref.watch(inlineRateProvider);
    if (rate.phase == InlineRatePhase.feedback) {
      return _WhatToFix(rating: rate.rating, run: mine ? run : null);
    }

    final phase = switch (mine ? run.phase : null) {
      ExportPhase.running => _Rendering(run: run!),
      ExportPhase.failed => _Failed(run: run!),
      ExportPhase.done => _Ready(run: run!),
      null => null,
    };
    if (phase == null) {
      return _Settings(
        busyWith: run?.phase == ExportPhase.running ? run!.projectTitle : null,
      );
    }
    // On the tablet's full-screen export the progress and the result read
    // as one comfortable column.
    if (EcPanelPresentation.maybeOf(context)?.fullScreen ?? false) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: phase,
        ),
      );
    }
    return phase;
  }
}

/// 6.1 — the locked facts first, so each render can be checked, then the
/// codec and resolution.
class _Settings extends ConsumerWidget {
  /// Another project already rendering — one render at a time.
  final String? busyWith;
  const _Settings({this.busyWith});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final project = ref.watch(projectControllerProvider);
    final export = ref.watch(exportControllerProvider);
    final controller = ref.read(exportControllerProvider.notifier);
    final e = project.engine;
    final capabilities = ref.watch(encoderCapabilitiesProvider);
    if (!capabilities.hasValue) {
      return EcSheet(
        title: 'Export',
        child: capabilities.hasError
            ? const Text(
                'Could not check export support. Close this panel and try again.',
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final device = capabilities.value;
    if (device == null || device.codecs.isEmpty) {
      return const EcSheet(
        title: 'Export',
        child: Text('This device has no supported export formats.'),
      );
    }

    final codec = export.codecFor(project.settings, device);
    final resolutions = export.resolutionsFor(codec, device, fps: e.fps);
    final isPro = ref.watch(entitlementProvider).value?.isPro ?? false;
    final resolution = export.resolutionFor(
      project.formatW,
      project.formatH,
      codec,
      device,
      isPro: isPro,
      fps: e.fps,
    );
    final access = export.accessFor(
      project.project.id,
      codec,
      resolution,
      isPro: isPro,
    );
    final (w, h) = resolution.sizeFor(project.formatW, project.formatH);
    final seconds = e.totalFrames / e.fps;
    final transparent = project.settings.background == MonitorBackground.alpha;
    final prefer60 =
        e.judderRisk &&
        e.fps < 60 &&
        device.supports60Fps(codec, resolution.edge);
    final unsupportedRate =
        e.fps > 30 && !device.supports60Fps(codec, resolution.edge);
    final wide = EcSheetPresentation.isDialog(context);

    final facts = [
      ('Format', '${project.formatW} × ${project.formatH}'),
      ('Frame rate', formatFps(e.fps)),
      ('Runtime', formatTimecode(e.totalFrames, e.fps)),
      ('Scroll rate', '${e.ppf.toStringAsFixed(2)} px/f'),
    ];

    if (context.tabletLayout case final layout?) {
      return _TabletSettings(
        portrait: layout == TabletLayout.portrait,
        facts: [
          '${project.formatW} × ${project.formatH}',
          formatFps(e.fps),
          formatTimecode(e.totalFrames, e.fps),
          '${e.ppf.toStringAsFixed(2)} px/f',
        ].join(' · '),
        codecs: [
          for (final c in device.codecs)
            _TabletCodecCard(
              codec: c,
              selected: c == codec,
              showPro: !isPro,
              size: formatBytes(estimateBytes(c, w, h, seconds)),
              onTap: () => controller.setCodec(c),
            ),
        ],
        resolution: EcSegmented(
          labels: [for (final r in resolutions) r.label],
          selectedIndex: resolutions.indexOf(resolution),
          onChanged: (i) => controller.setResolution(resolutions[i]),
          trailing: {
            if (!isPro)
              for (final (i, r) in resolutions.indexed)
                if (r.isPro) i: const EcGradientPill('Pro'),
          },
        ),
        notices: [
          if (unsupportedRate)
            EcNotice(
              tone: EcTone.warn,
              title: 'This device cannot export this frame rate',
              body: 'Use 30 fps and a slower scroll for smoother motion.',
              actions: [
                EcButton.secondary(
                  label: 'Use 30 fps · same runtime',
                  onPressed: () => ref.read(projectControllerProvider.notifier).setFps(30),
                ),
              ],
            ),
          if (transparent && !codec.alpha)
            EcNotice(
              tone: EcTone.warn,
              title: '${codec.label} has no alpha',
              body: 'The transparent background will render as black. ProRes 4444 or PNG keep it.',
            ),
          EcGroup(
            children: [
              EcGroupRow.toggle(
                title: 'Motion blur',
                subtitle: 'A film-style 180° shutter. Softens moving text; it does not remove judder.',
                value: project.settings.motionSmoothing,
                onChanged: ref.read(projectControllerProvider.notifier).setMotionSmoothing,
              ),
            ],
          ),
        ],
        locked: access == ExportAccess.locked,
        proTitle: _proTablet(codec, resolution),
        note: 'H.264 and HEVC up to 1080p are free, with no watermark. Estimated render '
            '${formatAbout(estimateRenderSeconds(w, h, seconds))}; it keeps running if you close this.',
        busyWith: busyWith,
        onWatchAd: busyWith != null ? null : () => _unlockWithAd(context, ref, _proLabel(codec, resolution)),
        onPro: ref.watch(iosFreeLaunchProvider) ? null : () => ProSheet.show(context),
        render: prefer60
            ? [
                EcButton(
                  label: 'Render ${codec.label} · 60 fps',
                  onPressed: busyWith != null ? null : controller.startAt60Fps,
                ),
                const SizedBox(height: 8),
                EcButton.secondary(
                  label: 'Render current ${formatFps(e.fps)}',
                  onPressed: busyWith != null ? null : controller.start,
                ),
              ]
            : [
                EcButton(
                  label: 'Render',
                  onPressed: busyWith != null || unsupportedRate ? null : controller.start,
                ),
              ],
        onEdit: () {
          // Off the export page first, then Timing from the editor under it.
          final navigator = Navigator.of(context);
          navigator.pop();
          TimingSheet.show(navigator.context);
        },
      );
    }

    return EcSheet(
      title: wide ? 'Render a master.' : 'Export',
      maxHeightFraction: 0.94,
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (access == ExportAccess.locked) ...[
              _ProPickCard(title: _proTitle(codec, resolution)),
              const SizedBox(height: 10),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Estimated render',
                      style: t.bodyS.copyWith(fontSize: 12, color: p.muted),
                    ),
                  ),
                  Text(
                    formatAbout(estimateRenderSeconds(w, h, seconds)),
                    style: t.mono.copyWith(fontSize: 12, color: p.ink),
                  ),
                ],
              ),
            ),
            if (wide && busyWith == null) ...[
              const SizedBox(height: 6),
              Text(
                'Estimated render ${formatAbout(estimateRenderSeconds(w, h, seconds))} · keeps running if you close this',
                style: t.caption,
              ),
            ],
            const SizedBox(height: 10),
            if (busyWith != null) ...[
              Text(
                'Rendering “$busyWith” — one render at a time.',
                textAlign: TextAlign.center,
                style: t.caption,
              ),
              const SizedBox(height: 8),
            ],
            if (access == ExportAccess.locked) ...[
              EcButton(
                label: '▶  Watch ad · render once',
                onPressed: busyWith != null
                    ? null
                    : () => _unlockWithAd(
                        context,
                        ref,
                        _proLabel(codec, resolution),
                      ),
              ),
              if (!ref.watch(iosFreeLaunchProvider)) ...[
                const SizedBox(height: 8),
                EcButton.secondary(
                  label: 'Go Pro · every render, no ads',
                  onPressed: () => ProSheet.show(context),
                ),
              ],
            ] else ...[
              if (prefer60) ...[
                Text(
                  '60 fps keeps the same runtime and scroll speed.',
                  textAlign: TextAlign.center,
                  style: t.caption,
                ),
                const SizedBox(height: 8),
                EcButton(
                  label: 'Render ${codec.label} · 60 fps',
                  onPressed: busyWith != null ? null : controller.startAt60Fps,
                ),
                const SizedBox(height: 8),
                EcButton.secondary(
                  label: 'Render current ${formatFps(e.fps)}',
                  onPressed: busyWith != null ? null : controller.start,
                ),
              ] else
                EcButton(
                  label: wide ? 'Render' : 'Render ${codec.label}',
                  onPressed: busyWith != null || unsupportedRate
                      ? null
                      : controller.start,
                ),
            ],
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(EcRadius.card),
              border: Border.all(color: p.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        caps('Locked for this render'),
                        style: t.section,
                      ),
                    ),
                    EcButton.text(
                      label: 'Edit',
                      size: EcButtonSize.small,
                      onPressed: () {
                        closeEcSheet(context);
                        TimingSheet.show(context);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  runSpacing: 10,
                  children: [
                    for (final (label, value) in facts)
                      FractionallySizedBox(
                        widthFactor: .5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: t.caption.copyWith(fontSize: 10.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              value,
                              style: t.mono.copyWith(
                                fontSize: 13,
                                color: p.ink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (unsupportedRate) ...[
            EcNotice(
              tone: EcTone.warn,
              title: 'This device cannot export this frame rate',
              body: 'Use 30 fps and a slower scroll for smoother motion.',
              actions: [
                EcButton.secondary(
                  label: 'Use 30 fps · same runtime',
                  onPressed: () =>
                      ref.read(projectControllerProvider.notifier).setFps(30),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          EcGroup(
            children: [
              EcGroupRow.toggle(
                title: 'Motion blur',
                subtitle:
                    'A film-style 180° shutter. Softens moving text; it does not remove judder.',
                value: project.settings.motionSmoothing,
                onChanged: ref
                    .read(projectControllerProvider.notifier)
                    .setMotionSmoothing,
              ),
            ],
          ),
          if (e.judderRisk || !e.readable) ...[
            const SizedBox(height: 10),
            EcNotice(
              tone: EcTone.warn,
              title: e.judderRisk
                  ? 'Fast motion may strobe'
                  : 'Names pass too quickly',
              body:
                  'Text moves ${formatPpf(e.ppf)} px per frame at ${formatFps(e.fps)}. '
                  'A whole-pixel speed does not guarantee smooth playback. '
                  'Try a slower roll or a higher frame rate.',
              actions: [
                if (e.judderRisk &&
                    e.fps < 60 &&
                    device.supports60Fps(codec, resolution.edge))
                  EcButton.secondary(
                    label: 'Use 60 fps · same runtime',
                    size: EcButtonSize.small,
                    onPressed: () =>
                        ref.read(projectControllerProvider.notifier).setFps(60),
                  ),
                if (timingFixes(e, count: 1) case [(final ppf, final frames)])
                  EcButton.secondary(
                    label: 'Use ${formatClock(frames / e.fps)} · $ppf px/f',
                    size: EcButtonSize.small,
                    onPressed: () => ref
                        .read(projectControllerProvider.notifier)
                        .applySnap(ppf),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const EcSectionLabel('Codec'),
          EcGroup(
            children: [
              for (final c in device.codecs)
                _CodecRow(
                  codec: c,
                  selected: c == codec,
                  showPro: !isPro,
                  // H.264 and HEVC are encoded at this rate; the others
                  // vary with the picture. Either way it's an estimate.
                  size: '≈ ${formatBytes(estimateBytes(c, w, h, seconds))}',
                  onTap: () => controller.setCodec(c),
                ),
            ],
          ),
          if (transparent && !codec.alpha) ...[
            const SizedBox(height: 10),
            EcNotice(
              tone: EcTone.warn,
              title: '${codec.label} has no alpha',
              body:
                  'The transparent background will render as black. ProRes 4444 or PNG keep it.',
            ),
          ],
          const SizedBox(height: 14),
          const EcSectionLabel('Resolution'),
          EcSegmented(
            labels: [for (final r in resolutions) r.label],
            selectedIndex: resolutions.indexOf(resolution),
            onChanged: (i) => controller.setResolution(resolutions[i]),
            trailing: {
              if (!isPro)
                for (final (i, r) in resolutions.indexed)
                  if (r.isPro) i: const EcGradientPill('Pro'),
            },
          ),
          if ((w, h) != (project.formatW, project.formatH)) ...[
            const SizedBox(height: 8),
            Text(
              '$w × $h',
              textAlign: TextAlign.center,
              style: t.mono.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

/// T6.1: "ProRes 422 HQ is a Pro format."
String _proTablet(Codec codec, ExportResolution resolution) => switch ((codec.isPro, resolution.isPro)) {
  (true, true) => '${codec.label} in ${resolution.label} is Pro.',
  (true, false) => '${codec.label} is a Pro format.',
  _ => '${resolution.label} is a Pro resolution.',
};

/// T6.1 / P6.1 — export on a tablet: what is locked, the formats as cards,
/// the resolution, then the action. Picking a Pro format on Free swaps
/// Render for the opt-in rewarded ad, with the Pro screen beside it.
/// Landscape puts the formats left and the rest right; portrait reads top
/// to bottom, the action at the foot.
class _TabletSettings extends ConsumerWidget {
  final bool portrait;
  final String facts;
  final List<Widget> codecs;
  final Widget resolution;
  final List<Widget> notices;
  final bool locked;
  final String proTitle;
  final String note;
  final String? busyWith;
  final VoidCallback? onWatchAd;
  final VoidCallback? onPro;
  final List<Widget> render;
  final VoidCallback onEdit;

  const _TabletSettings({
    required this.portrait,
    required this.facts,
    required this.codecs,
    required this.resolution,
    required this.notices,
    required this.locked,
    required this.proTitle,
    required this.note,
    required this.busyWith,
    required this.onWatchAd,
    required this.onPro,
    required this.render,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final title = ref.watch(projectControllerProvider.select((s) => s.name));

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(caps('Export · $title'), style: t.eyebrow.copyWith(fontSize: 10.5, letterSpacing: 10.5 * .14)),
              const SizedBox(height: 8),
              Semantics(header: true, child: Text('Render the roll.', style: t.displayL.copyWith(fontSize: 40))),
            ],
          ),
        ),
        EcCircleButton.tint(icon: Icons.close_rounded, size: 48, tooltip: 'Close', onPressed: () => closeEcSheet(context)),
      ],
    );
    final lockedBar = Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: portrait
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LOCKED FOR THIS RENDER', style: t.eyebrow.copyWith(fontSize: 9.5)),
                      const SizedBox(height: 4),
                      Text(facts, style: t.mono.copyWith(fontSize: 12.5, color: p.ink)),
                    ],
                  )
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Locked for this render  ', style: t.mono.copyWith(fontSize: 11.5, color: p.muted)),
                        TextSpan(text: facts, style: t.mono.copyWith(fontSize: 12, color: p.ink)),
                      ],
                    ),
                  ),
          ),
          EcButton.text(label: 'Edit', size: EcButtonSize.small, onPressed: onEdit),
        ],
      ),
    );
    final cards = <Widget>[
      for (final c in codecs) ...[c, const SizedBox(height: 8)],
    ];
    final busy = busyWith == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Rendering “$busyWith” — one render at a time.',
              textAlign: TextAlign.center,
              style: t.caption,
            ),
          );
    final proCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.accentWash,
        border: Border.all(color: p.accentLine),
        borderRadius: BorderRadius.circular(20),
      ),
      child: portrait
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$proTitle Watch one short ad to use it for this render. Each ad unlocks one render.',
                  style: t.body.copyWith(fontSize: 14, height: 1.45, color: p.ink2),
                ),
                const SizedBox(height: 12),
                ?busy,
                Row(
                  children: [
                    Expanded(
                      child: EcButton(
                        label: 'Watch ad & render',
                        variant: EcButtonVariant.ink,
                        height: 56,
                        onPressed: onWatchAd,
                      ),
                    ),
                    if (onPro != null) ...[
                      const SizedBox(width: 8),
                      EcButton.secondary(label: 'See Pro', height: 56, expand: false, onPressed: onPro),
                    ],
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(proTitle, style: t.titleM.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Watch one short ad to use it for this render. Each ad unlocks one render. '
                  '${onPro == null ? '' : 'Or get Pro for every render, with no ads.'}',
                  style: t.body.copyWith(fontSize: 13.5, height: 1.45, color: p.ink2),
                ),
                const SizedBox(height: 14),
                ?busy,
                EcButton(label: 'Watch ad · render once', height: 50, onPressed: onWatchAd),
                if (onPro != null) ...[
                  const SizedBox(height: 10),
                  EcButton.secondary(label: 'See LastReel Pro', height: 46, onPressed: onPro),
                ],
              ],
            ),
    );
    final action = locked
        ? proCard
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [?busy, ...render]);
    final resolutionBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        portrait
            ? Text('Resolution', style: t.label.copyWith(fontSize: 13, color: p.ink))
            : Text('RESOLUTION', style: t.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.4)),
        const SizedBox(height: 8),
        resolution,
      ],
    );
    final extras = [
      for (final n in notices) ...[n, const SizedBox(height: 12)],
    ];

    if (portrait) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    lockedBar,
                    const SizedBox(height: 14),
                    ...cards,
                    const SizedBox(height: 10),
                    resolutionBlock,
                    const SizedBox(height: 16),
                    ...extras,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            action,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 28, 30, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 14),
          lockedBar,
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: ListView(padding: EdgeInsets.zero, children: cards)),
                const SizedBox(width: 16),
                SizedBox(
                  width: 400,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      resolutionBlock,
                      const SizedBox(height: 18),
                      action,
                      const SizedBox(height: 14),
                      Text(note, style: t.caption.copyWith(fontSize: 12, height: 1.45)),
                      const SizedBox(height: 16),
                      ...extras,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A format on the tablet's export screen: a white card with a radio, the
/// name, "PRO" on Free, what it is for, and the size.
class _TabletCodecCard extends StatelessWidget {
  final Codec codec;
  final bool selected;
  final bool showPro;
  final String size;
  final VoidCallback onTap;

  const _TabletCodecCard({
    required this.codec,
    required this.selected,
    required this.showPro,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Semantics(
      selected: selected,
      button: true,
      label: codec.label,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? p.accentSolid : p.line, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: EcMotion.fast,
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.surface,
                    border: Border.all(color: selected ? p.accentSolid : p.line2, width: selected ? 6 : 1.5),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(codec.label, style: t.titleM.copyWith(fontSize: 15, fontWeight: FontWeight.w700))),
                          if (showPro && codec.isPro) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: p.inkSurface, borderRadius: BorderRadius.circular(999)),
                              child: Text('PRO', style: t.pill.copyWith(fontSize: 8.5, color: p.onInk, letterSpacing: .8)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        codec.alpha ? '${codec.description}, alpha' : codec.description,
                        style: t.bodyS.copyWith(fontSize: 12.5, color: p.muted),
                      ),
                    ],
                  ),
                ),
                Text(size, style: t.mono.copyWith(fontSize: 11.5, color: p.ink2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a Pro pick unlocks, as the ad and the card name it.
String _proLabel(Codec codec, ExportResolution resolution) =>
    switch ((codec.isPro, resolution.isPro)) {
      (true, true) => '${codec.label} in ${resolution.label}',
      (true, false) => codec.label,
      _ => resolution.label,
    };

String _proTitle(Codec codec, ExportResolution resolution) =>
    switch ((codec.isPro, resolution.isPro)) {
      (true, true) => '${codec.label} and ${resolution.label} are Pro',
      (true, false) => '${codec.label} is a Pro codec',
      _ => '${resolution.label} is a Pro resolution',
    };

/// Watches one rewarded ad (6.1a) and, if it's watched through, renders
/// with the chosen Pro settings. Closing it early unlocks nothing.
Future<void> _unlockWithAd(
  BuildContext context,
  WidgetRef ref,
  String unlocking,
) async {
  final controller = ref.read(exportControllerProvider.notifier);
  final outcome = await RewardedAdScreen.show(context, unlocking: unlocking);
  if (!context.mounted) return;
  switch (outcome) {
    case RewardOutcome.earned:
      if (context.isTablet) ref.read(analyticsProvider).logEvent('rewarded_ad_completed', {'format': unlocking});
      controller.grantPass();
      controller.start();
    case RewardOutcome.closedEarly:
      showEcToast(context, 'Ad closed early — nothing unlocked');
    case RewardOutcome.unavailable:
      showEcToast(
        context,
        'No ad available right now — try again in a moment, or go Pro',
      );
  }
}

/// "ProRes 422 HQ is a Pro codec — watch a 30-second ad to use it for this
/// render." Shown in place of the render button's context on the free plan.
class _ProPickCard extends StatelessWidget {
  final String title;
  const _ProPickCard({required this.title});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.accentWash,
        border: Border.all(color: p.accentLine),
        borderRadius: BorderRadius.circular(EcRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: p.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.play_arrow_rounded, size: 16, color: p.onInk),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleS.copyWith(fontSize: 13.5)),
                const SizedBox(height: 3),
                Text(
                  'Watch a 30-second ad to use it for this render. Each ad unlocks one render.',
                  style: t.bodyS.copyWith(
                    fontSize: 12,
                    color: p.ink2,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodecRow extends StatelessWidget {
  final Codec codec;
  final bool selected;
  final bool showPro;
  final String size;
  final VoidCallback onTap;

  const _CodecRow({
    required this.codec,
    required this.selected,
    required this.showPro,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          color: selected ? p.accentWash : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              AnimatedContainer(
                duration: EcMotion.fast,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected ? p.primary : null,
                  border: selected
                      ? null
                      : Border.all(color: p.line2, width: 1.5),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 14, color: p.onInk)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            codec.label,
                            style: t.titleS.copyWith(fontSize: 13.5),
                          ),
                        ),
                        if (showPro && codec.isPro) ...[
                          const SizedBox(width: 6),
                          const EcGradientPill('Pro'),
                        ],
                        if (codec.alpha) ...[
                          const SizedBox(width: 6),
                          const EcStatusPill('Alpha', tone: EcTone.accent),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(codec.description, style: t.caption),
                  ],
                ),
              ),
              Text(size, style: t.mono.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 8 px render progress bar: a tint track with the gradient fill.
class RenderProgressBar extends StatelessWidget {
  final double progress;
  const RenderProgressBar(this.progress, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(EcRadius.pill),
      child: Container(
        height: 8,
        color: p.tint,
        alignment: Alignment.centerLeft,
        // heightFactor 1: the Container's alignment loosens the height, and
        // a childless box would otherwise be 0 tall — an empty-looking bar.
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0, 1),
          heightFactor: 1,
          child: DecoratedBox(decoration: BoxDecoration(gradient: p.primary)),
        ),
      ),
    );
  }
}

/// 6.2 — progress, and on the free plan the one ad, in the wait the
/// encoder already causes. The render carries on if the sheet closes.
class _Rendering extends ConsumerWidget {
  final ExportRun run;
  const _Rendering({required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final controller = ref.read(exportControllerProvider.notifier);
    final pct = (run.progress * 100).floor();

    return EcSheet(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Row(
          children: [
            Expanded(
              child: EcHeadline('Rendering', emphasis: '…', style: t.displayM),
            ),
            EcCircleButton.tint(
              icon: Icons.close_rounded,
              size: 34,
              tooltip: 'Close',
              onPressed: () => closeEcSheet(context),
            ),
          ],
        ),
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EcButton.secondary(
              label: 'Keep working · renders in background',
              onPressed: () => closeEcSheet(context),
            ),
            const SizedBox(height: 4),
            EcButton.text(label: 'Cancel render', onPressed: controller.cancel),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(EcRadius.group),
              border: Border.all(color: p.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 88,
                      height: 50,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: p.monitor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        run.projectTitle.toUpperCase(),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: t.pill.copyWith(
                          fontSize: 7,
                          color: Colors.white.withValues(alpha: .85),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${run.codec.label} · ${run.width} × ${run.height}',
                            style: t.titleS.copyWith(fontSize: 13.5),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'frame ${run.frame} / ${run.totalFrames}',
                            style: t.mono.copyWith(fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: t.displayM.copyWith(fontSize: 34, color: p.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RenderProgressBar(run.progress),
                const SizedBox(height: 12),
                Text(
                  run.frame == 0
                      ? 'Preparing…'
                      : '${formatAbout(run.secondsLeft)} left',
                  style: t.mono.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const RateSlot(
            ad: SponsoredSlot(
              AdPlacement.rendering,
              label: 'Sponsored · while you wait',
              hideLabel: 'Remove ads',
              gap: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatToFix extends ConsumerWidget {
  final int rating;
  final ExportRun? run;
  const _WhatToFix({required this.rating, required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final run = this.run;
    final container = ProviderScope.containerOf(context, listen: false);
    void finish(RatingFeedback? report) {
      ReviewPrompt.sendToTeam(container, report, rating);
      ref.read(inlineRateProvider.notifier).close();
    }

    return EcSheet(
      header: run == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Text(
                    run.phase == ExportPhase.done ? 'Ready' : 'Rendering',
                    style: t.titleS.copyWith(fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: RenderProgressBar(run.progress)),
                  const SizedBox(width: 12),
                  Text(
                    run.phase == ExportPhase.done
                        ? '100%'
                        : '${(run.progress * 100).floor()}% · ${formatClock(run.secondsLeft.toDouble())}',
                    style: t.mono.copyWith(fontSize: 10.5, color: p.accent),
                  ),
                ],
              ),
            ),
      child: ReviewFeedbackForm(
        rating: rating,
        onSend: finish,
        onSkip: () => finish(null),
      ),
    );
  }
}

/// 6.3 — the cause, the size and the fix. No ad: a failure is a problem to
/// solve, not dead time.
class _Failed extends ConsumerWidget {
  final ExportRun run;
  const _Failed({required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final controller = ref.read(exportControllerProvider.notifier);
    final pct = (run.progress * 100).floor();
    final noSpace = run.failure == EncoderFailureKind.outOfSpace;
    final canLower =
        run.width > ExportResolution.hd.edge ||
        run.height > ExportResolution.hd.edge;

    final (headline, emphasis, body) = noSpace
        ? (
            'Not enough ',
            'free space.',
            kIsWeb
                ? '${run.failureMessage ?? 'Browser storage is full.'} Try a lower resolution or free some space.'
                : 'The file needs about ${formatBytes(run.neededBytes ?? run.bytes)}. '
                      '${canLower ? 'Free up space or drop to 1920' : 'Free up space'}, then try again.',
          )
        : (
            'The render ',
            'stopped.',
            '${run.failureMessage ?? 'The encoder stopped.'} Nothing was saved; try again, '
                '${run.codec == Codec.h264 ? 'or' : 'or pick H.264,'} a lower resolution.',
          );

    return EcSheet(
      showClose: false,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: EcButton(
                    label: 'Try again',
                    onPressed: controller.retry,
                  ),
                ),
                if (canLower) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: EcButton.secondary(
                      label: 'Lower resolution',
                      onPressed: controller.retryAtLowerResolution,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            EcButton.text(
              label: 'Back to settings',
              onPressed: controller.dismiss,
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.warnWash,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.priority_high_rounded, color: p.warn, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            caps('Stopped at $pct%'),
            style: t.eyebrow.copyWith(color: p.warn),
          ),
          const SizedBox(height: 8),
          EcHeadline(
            headline,
            emphasis: emphasis,
            style: t.displayM.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: t.body.copyWith(fontSize: 13, color: p.ink2, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// 6.4 — destinations only. No upsell at the moment the file lands.
class _Ready extends ConsumerWidget {
  final ExportRun run;
  const _Ready({required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final destinations = ref.read(exportDestinationsProvider);
    final path = run.outputPath!;
    final artifact =
        run.artifact ??
        ExportArtifact(
          location: path,
          filename: basename(path),
          mimeType: 'video/mp4',
          bytes: run.fileBytes ?? 0,
        );
    final facts = [
      run.codec.label,
      '${run.width} × ${run.height}',
      formatFps(run.fps),
      formatBytes((run.fileBytes ?? 0).toDouble()),
      formatClock(run.seconds),
    ].join(' · ');

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

    return EcSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: p.ok,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: p.ok.withValues(alpha: .7),
                    offset: const Offset(0, 12),
                    blurRadius: 28,
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: Icon(Icons.check_rounded, color: p.onInk, size: 28),
            ),
          ),
          const SizedBox(height: 16),
          EcHeadline(
            'Ready',
            emphasis: '.',
            style: t.displayM.copyWith(fontSize: 34),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            facts,
            textAlign: TextAlign.center,
            style: t.mono.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 20),
          EcGroup(
            children: [
              EcGroupRow(
                title: kIsWeb ? 'Download' : 'Save to Files',
                subtitle: basename(path),
                onTap: () => deliver(
                  kIsWeb
                      ? destinations.download(artifact)
                      : destinations.share(artifact, origin: origin()),
                ),
              ),
              // Photos holds video; an image sequence goes to Files.
              if (!kIsWeb && run.codec != Codec.png)
                EcGroupRow(
                  title: 'Save to Photos',
                  onTap: () => deliver(
                    destinations.saveToPhotos(artifact),
                    done: 'Saved to Photos',
                  ),
                ),
              if (!kIsWeb)
                EcGroupRow(
                  title: 'Send to Frame.io',
                  chevron: false,
                  trailing: const EcStatusPill('Soon'),
                  onTap: () => showEcToast(
                    context,
                    'Frame.io is coming soon — share the file for now',
                  ),
                ),
              if (destinations.canShare(artifact))
                EcGroupRow(
                  title: 'Share sheet',
                  onTap: () =>
                      deliver(destinations.share(artifact, origin: origin())),
                ),
            ],
          ),
          // The file has saved by the time this shows; the ad sits below
          // every destination and never stands between the user and them.
          // The tablet's one export ad is the wait's (§5): none once done.
          RateSlot(
            ad: context.isTablet
                ? const SizedBox.shrink()
                : const SponsoredSlot(
                    AdPlacement.exportComplete,
                    hideLabel: 'Remove ads',
                    gap: 20,
                  ),
          ),
        ],
      ),
    );
  }
}
