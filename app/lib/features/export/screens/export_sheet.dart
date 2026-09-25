import 'package:flutter/material.dart';
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
import '../../../core/widgets/ec_surfaces.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../../domain/models/project_settings.dart';
import '../../plan/screens/pro_sheet.dart';
import '../../project/controllers/project_controller.dart';
import '../../timing/screens/timing_sheet.dart';
import '../controllers/export_controller.dart';
import '../models/export_models.dart';

/// Export: settings (6.1), rendering (6.2), failed (6.3), ready (6.4).
///
/// Free and Pro render exactly the same file — every codec and resolution,
/// no watermark, no end card. The only difference is the one ad while a
/// free render encodes.
class ExportSheet extends ConsumerWidget {
  const ExportSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    await showEcSheet<void>(context, builder: (_) => const ExportSheet());
    // A delivered file is done with; a failure stays, to be resumed.
    if (container.read(exportControllerProvider).run?.phase == ExportPhase.done) {
      container.read(exportControllerProvider.notifier).dismiss();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = ref.watch(projectControllerProvider.select((s) => s.project.id));
    final run = ref.watch(exportControllerProvider.select((s) => s.run));
    final mine = run != null && run.projectId == projectId;

    return switch (mine ? run.phase : null) {
      ExportPhase.running => _Rendering(run: run!),
      ExportPhase.failed => _Failed(run: run!),
      ExportPhase.done => _Ready(run: run!),
      null => _Settings(busyWith: run?.phase == ExportPhase.running ? run!.projectTitle : null),
    };
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
    final device = ref.watch(encoderCapabilitiesProvider).value;
    final codec = export.codecFor(project.settings, device);
    final resolutions = export.resolutionsFor(codec, device);
    final isPro = ref.watch(entitlementProvider).value?.isPro ?? false;
    final resolution = export.resolutionFor(project.formatW, project.formatH, codec, device, isPro: isPro);
    final access = export.accessFor(project.project.id, codec, resolution, isPro: isPro);
    final (w, h) = resolution.sizeFor(project.formatW, project.formatH);
    final seconds = e.totalFrames / e.fps;
    final transparent = project.settings.background == MonitorBackground.alpha;

    final facts = [
      ('Format', '${project.formatW} × ${project.formatH}'),
      ('Frame rate', formatFps(e.fps)),
      ('Runtime', formatTimecode(e.totalFrames, e.fps)),
      ('Scroll rate', '${e.ppf.toStringAsFixed(2)} px/f'),
    ];

    return EcSheet(
      title: 'Export',
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
                  Expanded(child: Text('Estimated render', style: t.bodyS.copyWith(fontSize: 12, color: p.muted))),
                  Text(formatAbout(estimateRenderSeconds(w, h, seconds)), style: t.mono.copyWith(fontSize: 12, color: p.ink)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (busyWith != null) ...[
              Text('Rendering “$busyWith” — one render at a time.', textAlign: TextAlign.center, style: t.caption),
              const SizedBox(height: 8),
            ],
            if (access == ExportAccess.locked) ...[
              EcButton(
                label: '▶  Watch ad · render once',
                onPressed: busyWith != null ? null : () => _unlockWithAd(context, ref, _proLabel(codec, resolution)),
              ),
              const SizedBox(height: 8),
              EcButton.secondary(label: 'Go Pro · every render, no ads', onPressed: () => ProSheet.show(context)),
            ] else
              EcButton(label: 'Render ${codec.label}', onPressed: busyWith != null ? null : controller.start),
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
                    Expanded(child: Text(caps('Locked for this render'), style: t.section)),
                    EcButton.text(
                      label: 'Edit',
                      size: EcButtonSize.small,
                      onPressed: () {
                        Navigator.of(context).pop();
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
                            Text(label, style: t.caption.copyWith(fontSize: 10.5)),
                            const SizedBox(height: 2),
                            Text(value, style: t.mono.copyWith(fontSize: 13, color: p.ink, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (!e.clean)
            if (timingFixes(e, count: 1) case [(final ppf, final frames)]) ...[
              const SizedBox(height: 10),
              EcNotice(
                tone: EcTone.warn,
                title: 'Moves ${formatPpf(e.ppf)} px a frame',
                body: 'It will roll evenly, but a fractional speed is drawn between pixels and can look '
                    'slightly soft. A whole number of pixels is crisper.',
                actions: [
                  EcButton.secondary(
                    label: 'Use ${formatClock(frames / e.fps)} · $ppf px/f',
                    size: EcButtonSize.small,
                    onPressed: () => ref.read(projectControllerProvider.notifier).applySnap(ppf),
                  ),
                ],
              ),
            ],
          const SizedBox(height: 14),
          const EcSectionLabel('Codec'),
          EcGroup(children: [
            if (device == null)
              const EcGroupRow(title: 'Checking what this device can encode…', chevron: false)
            else
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
          ]),
          if (transparent && !codec.alpha) ...[
            const SizedBox(height: 10),
            EcNotice(
              tone: EcTone.warn,
              title: '${codec.label} has no alpha',
              body: 'The transparent background will render as black. ProRes 4444 or PNG keep it.',
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
            Text('$w × $h', textAlign: TextAlign.center, style: t.mono.copyWith(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

/// What a Pro pick unlocks, as the ad and the card name it.
String _proLabel(Codec codec, ExportResolution resolution) => switch ((codec.isPro, resolution.isPro)) {
      (true, true) => '${codec.label} in ${resolution.label}',
      (true, false) => codec.label,
      _ => resolution.label,
    };

String _proTitle(Codec codec, ExportResolution resolution) => switch ((codec.isPro, resolution.isPro)) {
      (true, true) => '${codec.label} and ${resolution.label} are Pro',
      (true, false) => '${codec.label} is a Pro codec',
      _ => '${resolution.label} is a Pro resolution',
    };

/// Watches one rewarded ad (6.1a) and, if it's watched through, renders
/// with the chosen Pro settings. Closing it early unlocks nothing.
Future<void> _unlockWithAd(BuildContext context, WidgetRef ref, String unlocking) async {
  final controller = ref.read(exportControllerProvider.notifier);
  final outcome = await RewardedAdScreen.show(context, unlocking: unlocking);
  if (!context.mounted) return;
  switch (outcome) {
    case RewardOutcome.earned:
      controller.grantPass();
      controller.start();
    case RewardOutcome.closedEarly:
      showEcToast(context, 'Ad closed early — nothing unlocked');
    case RewardOutcome.unavailable:
      showEcToast(context, 'No ad available right now — try again in a moment, or go Pro');
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
            decoration: BoxDecoration(gradient: p.primary, shape: BoxShape.circle),
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
                  style: t.bodyS.copyWith(fontSize: 12, color: p.ink2, height: 1.45),
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
                  border: selected ? null : Border.all(color: p.line2, width: 1.5),
                ),
                child: selected ? Icon(Icons.check_rounded, size: 14, color: p.onInk) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(codec.label, style: t.titleS.copyWith(fontSize: 13.5))),
                        if (showPro && codec.isPro) ...[const SizedBox(width: 6), const EcGradientPill('Pro')],
                        if (codec.alpha) ...[const SizedBox(width: 6), const EcStatusPill('Alpha', tone: EcTone.accent)],
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
            Expanded(child: EcHeadline('Rendering', emphasis: '…', style: t.displayM)),
            EcCircleButton.tint(
              icon: Icons.close_rounded,
              size: 34,
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
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
              onPressed: () => Navigator.of(context).maybePop(),
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
                      decoration: BoxDecoration(color: p.monitor, borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        run.projectTitle.toUpperCase(),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: t.pill.copyWith(fontSize: 7, color: Colors.white.withValues(alpha: .85)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${run.codec.label} · ${run.width} × ${run.height}', style: t.titleS.copyWith(fontSize: 13.5)),
                          const SizedBox(height: 3),
                          Text('frame ${run.frame} / ${run.totalFrames}', style: t.mono.copyWith(fontSize: 10.5)),
                        ],
                      ),
                    ),
                    Text('$pct%', style: t.displayM.copyWith(fontSize: 34, color: p.accent)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(EcRadius.pill),
                  child: Container(
                    height: 8,
                    color: p.tint,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: run.progress,
                      child: DecoratedBox(decoration: BoxDecoration(gradient: p.primary)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  run.frame == 0 ? 'Preparing…' : '${formatAbout(run.secondsLeft)} left',
                  style: t.mono.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SponsoredSlot(
            AdPlacement.rendering,
            label: 'Sponsored · while you wait',
            hideLabel: 'Remove ads',
            gap: 14,
          ),
        ],
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
    final canLower = run.width > ExportResolution.hd.edge || run.height > ExportResolution.hd.edge;

    final (headline, emphasis, body) = noSpace
        ? (
            'Not enough ',
            'free space.',
            'The file needs about ${formatBytes(run.neededBytes ?? run.bytes)}. '
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
                Expanded(child: EcButton(label: 'Try again', onPressed: controller.retry)),
                if (canLower) ...[
                  const SizedBox(width: 8),
                  Expanded(child: EcButton.secondary(label: 'Lower resolution', onPressed: controller.retryAtLowerResolution)),
                ],
              ],
            ),
            const SizedBox(height: 4),
            EcButton.text(label: 'Back to settings', onPressed: controller.dismiss),
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
            decoration: BoxDecoration(color: p.warnWash, shape: BoxShape.circle),
            child: Icon(Icons.priority_high_rounded, color: p.warn, size: 26),
          ),
          const SizedBox(height: 16),
          Text(caps('Stopped at $pct%'), style: t.eyebrow.copyWith(color: p.warn)),
          const SizedBox(height: 8),
          EcHeadline(headline, emphasis: emphasis, style: t.displayM.copyWith(fontSize: 32)),
          const SizedBox(height: 10),
          Text(body, style: t.body.copyWith(fontSize: 13, color: p.ink2, height: 1.5)),
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
                boxShadow: [BoxShadow(color: p.ok.withValues(alpha: .7), offset: const Offset(0, 12), blurRadius: 28, spreadRadius: -10)],
              ),
              child: Icon(Icons.check_rounded, color: p.onInk, size: 28),
            ),
          ),
          const SizedBox(height: 16),
          EcHeadline('Ready', emphasis: '.', style: t.displayM.copyWith(fontSize: 34), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(facts, textAlign: TextAlign.center, style: t.mono.copyWith(fontSize: 11)),
          const SizedBox(height: 20),
          EcGroup(children: [
            EcGroupRow(
              title: 'Save to Files',
              subtitle: basename(path),
              onTap: () => deliver(destinations.share(path, origin: origin())),
            ),
            // Photos holds video; an image sequence goes to Files.
            if (run.codec != Codec.png)
              EcGroupRow(
                title: 'Save to Photos',
                onTap: () => deliver(destinations.saveToPhotos(path), done: 'Saved to Photos'),
              ),
            EcGroupRow(
              title: 'Send to Frame.io',
              chevron: false,
              trailing: const EcStatusPill('Soon'),
              onTap: () => showEcToast(context, 'Frame.io is coming soon — share the file for now'),
            ),
            EcGroupRow(title: 'Share sheet', onTap: () => deliver(destinations.share(path, origin: origin()))),
          ]),
          // The file has saved by the time this shows; the ad sits below
          // every destination and never stands between the user and them.
          const SponsoredSlot(AdPlacement.exportComplete, hideLabel: 'Remove ads', gap: 20),
        ],
      ),
    );
  }
}
