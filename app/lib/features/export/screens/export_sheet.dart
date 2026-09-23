import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_ad_slot.dart';
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
    final codec = export.codecFor(project.settings);
    final resolution = export.resolutionFor(project.formatW);
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
          const SizedBox(height: 14),
          const EcSectionLabel('Codec'),
          EcGroup(children: [
            for (final c in Codec.values)
              _CodecRow(
                codec: c,
                selected: c == codec,
                size: formatBytes(estimateBytes(c, w, h, seconds)),
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
            labels: [for (final r in ExportResolution.values) r.label],
            selectedIndex: resolution.index,
            onChanged: (i) => controller.setResolution(ExportResolution.values[i]),
          ),
        ],
      ),
    );
  }
}

class _CodecRow extends StatelessWidget {
  final Codec codec;
  final bool selected;
  final String size;
  final VoidCallback onTap;

  const _CodecRow({required this.codec, required this.selected, required this.size, required this.onTap});

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
    final showsAds = ref.watch(entitlementProvider).value?.showsAds ?? true;
    final pct = (run.progress * 100).round();

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
        child: EcButton.secondary(
          label: 'Keep working · renders in background',
          onPressed: () => Navigator.of(context).maybePop(),
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
                Text('${formatAbout(run.secondsLeft)} left', style: t.mono.copyWith(fontSize: 10.5)),
              ],
            ),
          ),
          if (showsAds) ...[
            const SizedBox(height: 14),
            EcAdSlot(
              label: 'Sponsored · while you wait',
              hideLabel: 'Remove ads',
              headline: 'Artlist — royalty-free score',
              body: 'Static, silent, gone when the render ends.',
              onHideAds: () => ProSheet.show(context),
            ),
          ],
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
    final pct = (run.progress * 100).round();
    final canLower = run.width > ExportResolution.hd.width;

    return EcSheet(
      showClose: false,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Expanded(child: EcButton(label: 'Resume', onPressed: controller.resume)),
            if (canLower) ...[
              const SizedBox(width: 8),
              Expanded(child: EcButton.secondary(label: 'Lower resolution', onPressed: controller.resumeAtLowerResolution)),
            ],
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
          EcHeadline('Not enough ', emphasis: 'free space.', style: t.displayM.copyWith(fontSize: 32)),
          const SizedBox(height: 10),
          Text(
            'The file needs ${formatBytes(run.neededBytes ?? run.bytes)}. '
            '${canLower ? 'Free up space or drop to 1080p' : 'Free up space'} — the first $pct% is cached, '
            'so the retry picks up where it stopped.',
            style: t.body.copyWith(fontSize: 13, color: p.ink2, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// 6.4 — destinations only. No upsell at the moment the file lands.
class _Ready extends StatelessWidget {
  final ExportRun run;
  const _Ready({required this.run});

  static const _destinations = ['Save to Files', 'Save to Photos', 'Send to Frame.io', 'Share sheet'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final facts = [
      run.codec.label,
      '${run.width} × ${run.height}',
      formatFps(run.fps),
      formatBytes(run.bytes),
      formatClock(run.seconds),
    ].join(' · ');

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
            for (final d in _destinations)
              EcGroupRow(
                title: d,
                // This build simulates the encode, so there is no file to
                // hand over yet — say so rather than pretend.
                onTap: () => showEcToast(context, 'This preview build doesn’t write a file yet'),
              ),
          ]),
        ],
      ),
    );
  }
}
