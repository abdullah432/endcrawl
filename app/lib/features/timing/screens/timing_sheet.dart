import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_chip.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_stepper.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../../domain/models/project_settings.dart';
import '../../editor/controllers/editor_ui_controller.dart';
import '../../project/controllers/project_controller.dart';

/// 5.1 — runtime in, scroll rate out, the way a delivery spec arrives; or
/// lock the speed and read the runtime. Judder and dwell are reported
/// separately so it's clear which one is the problem.
class TimingSheet extends ConsumerWidget {
  const TimingSheet({super.key});

  static Future<void> show(BuildContext context) => showEcSheet<void>(context, builder: (_) => const TimingSheet());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final project = ref.watch(projectControllerProvider);
    final controller = ref.read(projectControllerProvider.notifier);
    final settings = project.settings;
    final e = project.engine;
    final byRuntime = settings.mode == TimingMode.duration;
    final neighbours = neighbourRates(e);
    final runtimeSeconds = e.totalFrames / e.fps;

    // Any change here is a new timing decision, so a dismissed warning
    // comes back if the new timing has the problem too.
    void edit(VoidCallback change) {
      change();
      ref.read(editorUiControllerProvider.notifier).resetWarn();
    }

    final timecode = formatTimecode(e.totalFrames, e.fps);
    final input = byRuntime
        ? _InputCard(
            label: 'Runtime · the input',
            value: Text.rich(TextSpan(children: [
              TextSpan(text: timecode.substring(0, 8)),
              TextSpan(text: timecode.substring(8), style: TextStyle(color: p.faint)),
            ])),
            decrementLabel: 'Shorter by a second',
            incrementLabel: 'Longer by a second',
            onDec: () => edit(controller.durationDown),
            onInc: () => edit(controller.durationUp),
            derived: 'Derived scroll rate · ',
            derivedValue: '${e.ppf.toStringAsFixed(2)} px/frame',
          )
        : _InputCard(
            label: 'Speed · the input',
            value: Text('${formatPpf(e.ppf)} px/frame'),
            decrementLabel: 'Slower',
            incrementLabel: 'Faster',
            onDec: e.ppf <= 1 ? null : () => edit(() => controller.setPpf((e.ppf - 1).roundToDouble())),
            onInc: () => edit(() => controller.setPpf((e.ppf + 1).roundToDouble())),
            derived: 'Derived runtime · ',
            derivedValue: timecode,
          );

    return EcSheet(
      title: 'Timing',
      maxHeightFraction: 0.92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EcSegmented(
            labels: const ['Lock runtime', 'Lock speed'],
            selectedIndex: byRuntime ? 0 : 1,
            onChanged: (i) => edit(i == 0 ? controller.setModeDuration : controller.setModeSpeed),
          ),
          const SizedBox(height: 14),
          input,
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Verdict(
                  ok: e.clean,
                  title: e.clean ? 'No judder' : 'Judder',
                  detail: e.clean ? 'Whole pixel at ${project.formatW}' : '${e.ppf.toStringAsFixed(2)} px/frame is fractional',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Verdict(
                  ok: e.readable,
                  title: e.readable ? 'Readable' : 'Too fast',
                  detail: '${e.dwellSeconds.toStringAsFixed(1)}s dwell · floor 3.0s',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Nearest whole-pixel runtimes', style: t.bodyS.copyWith(fontSize: 12, color: p.ink2)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, rate) in [neighbours.shorter, neighbours.longer].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: rate == null
                      ? const SizedBox.shrink()
                      : _NeighbourCard(
                          ppf: rate.$1,
                          seconds: rate.$2 / e.fps,
                          currentSeconds: runtimeSeconds,
                          onTap: () => edit(() => controller.applySnap(rate.$1)),
                        ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _EdgeCard(
                  label: 'Head black',
                  value: formatSecondsFrames(settings.headSeconds, e.fps),
                  onDec: settings.headSeconds <= 0 ? null : () => edit(controller.headDown),
                  onInc: () => edit(controller.headUp),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EdgeCard(
                  label: 'Tail black',
                  value: formatSecondsFrames(settings.tailSeconds, e.fps),
                  onDec: settings.tailSeconds <= 0 ? null : () => edit(controller.tailDown),
                  onInc: () => edit(controller.tailUp),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final String label;
  final Widget value;
  final String decrementLabel;
  final String incrementLabel;
  final VoidCallback? onDec;
  final VoidCallback? onInc;
  final String derived;
  final String derivedValue;

  const _InputCard({
    required this.label,
    required this.value,
    required this.decrementLabel,
    required this.incrementLabel,
    required this.onDec,
    required this.onInc,
    required this.derived,
    required this.derivedValue,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(EcRadius.group),
        border: Border.all(color: p.line),
        boxShadow: p.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(caps(label), style: t.section),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: DefaultTextStyle(style: t.timecode, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: value))),
              const SizedBox(width: 10),
              EcCircleButton.tint(icon: Icons.remove_rounded, size: 44, tooltip: decrementLabel, onPressed: onDec),
              const SizedBox(width: 6),
              EcCircleButton.tint(icon: Icons.add_rounded, size: 44, tooltip: incrementLabel, onPressed: onInc),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: p.line),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: derived),
              TextSpan(text: derivedValue, style: t.mono.copyWith(fontSize: 12, color: p.ink, fontWeight: FontWeight.w500)),
            ]),
            style: t.bodyS.copyWith(fontSize: 12, color: p.muted),
          ),
        ],
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  final bool ok;
  final String title;
  final String detail;
  const _Verdict({required this.ok, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final fg = ok ? p.ok : p.warn;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: ok ? p.okWash : p.warnWash, borderRadius: BorderRadius.circular(EcRadius.row)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_rounded : Icons.priority_high_rounded, size: 14, color: fg),
              const SizedBox(width: 6),
              Flexible(child: Text(title, style: t.bodyS.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: fg))),
            ],
          ),
          const SizedBox(height: 4),
          Text(detail, style: t.mono.copyWith(fontSize: 10.5, color: p.ink2)),
        ],
      ),
    );
  }
}

class _NeighbourCard extends StatelessWidget {
  final int ppf;
  final double seconds;
  final double currentSeconds;
  final VoidCallback onTap;

  const _NeighbourCard({required this.ppf, required this.seconds, required this.currentSeconds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final delta = (seconds - currentSeconds).round();
    final change = delta == 0 ? 'same length' : '${delta.abs()}s ${delta < 0 ? 'shorter' : 'longer'}';
    final shape = BorderRadius.circular(EcRadius.row);
    return Material(
      type: MaterialType.transparency,
      borderRadius: shape,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(color: p.accentWash, borderRadius: shape, border: Border.all(color: p.accentLine)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(formatRuntime(Duration(milliseconds: (seconds * 1000).round())),
                    style: t.monoM.copyWith(fontSize: 15, color: p.accent, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text('$ppf px/f · $change', style: t.caption.copyWith(fontSize: 11), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgeCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onDec;
  final VoidCallback? onInc;

  const _EdgeCard({required this.label, required this.value, required this.onDec, required this.onInc});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(EcRadius.row), border: Border.all(color: p.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: context.type.caption),
          const SizedBox(height: 8),
          EcStepper(display: value, onDec: onDec, onInc: onInc),
        ],
      ),
    );
  }
}
