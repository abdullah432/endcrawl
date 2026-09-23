import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../project/controllers/project_controller.dart';
import '../controllers/editor_ui_controller.dart';
import 'status_line.dart';

/// 3.2 — the number, the cause, and the nearest clean runtimes as one-tap
/// fixes. Never blocks: "Ignore" hides it until the timing changes again.
class ReadabilityBanner extends ConsumerWidget {
  const ReadabilityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectControllerProvider);
    final dismissed = ref.watch(editorUiControllerProvider.select((s) => s.warnDismissed));
    final health = rollHealth(project);
    if (health == RollHealth.clean || dismissed || project.blocks.isEmpty) return const SizedBox.shrink();

    final p = context.palette;
    final t = context.type;
    final e = project.engine;
    final runtime = formatClock(project.runtime.inMilliseconds / 1000);
    final dwell = '${e.dwellSeconds.toStringAsFixed(1)}s';
    final (lead, cause) = switch (health) {
      RollHealth.judder => (
          '$runtime will judder.',
          [
            '${formatPpf(e.ppf)} px/frame is fractional',
            if (!e.readable) 'and each name is on screen $dwell — under the 3.0s floor',
          ].join(', '),
        ),
      _ => ('$runtime is too fast to read.', 'Each name is on screen $dwell — under the 3.0s floor'),
    };
    final fixes = timingFixes(e);
    final controller = ref.read(projectControllerProvider.notifier);
    final ui = ref.read(editorUiControllerProvider.notifier);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(EcRadius.card),
        border: Border.all(color: p.warnLine),
        boxShadow: [BoxShadow(color: p.warn.withValues(alpha: .5), offset: const Offset(0, 14), blurRadius: 28, spreadRadius: -20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.warnWash, shape: BoxShape.circle),
                child: Text('!', style: t.bodyS.copyWith(color: p.warn, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$lead ', style: TextStyle(fontWeight: FontWeight.w700, color: p.ink)),
                    TextSpan(text: '$cause.'),
                  ]),
                  style: t.bodyS.copyWith(fontSize: 12.5, height: 1.45, color: p.ink2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, (ppf, frames)) in fixes.indexed)
                _FixChip(
                  label: '${formatClock(frames / e.fps)} · $ppf px/f',
                  primary: i == 0,
                  onTap: () {
                    controller.applySnap(ppf);
                    ui.resetWarn();
                  },
                ),
              TextButton(
                onPressed: ui.dismissWarn,
                style: TextButton.styleFrom(
                  foregroundColor: p.muted,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: t.bodyS.copyWith(fontSize: 12),
                ),
                child: const Text('Ignore'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FixChip extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _FixChip({required this.label, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = BorderRadius.circular(EcRadius.pill);
    return Material(
      type: MaterialType.transparency,
      borderRadius: shape,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        height: 36,
        decoration: BoxDecoration(
          gradient: primary ? p.primary : null,
          color: primary ? null : p.accentWash,
          borderRadius: shape,
          border: primary ? null : Border.all(color: p.accentLine),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: context.type.mono.copyWith(fontSize: 11.5, color: primary ? p.onInk : p.accent, fontWeight: primary ? FontWeight.w500 : null),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
