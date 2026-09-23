import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../domain/models/project_settings.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../project/controllers/project_controller.dart';
import 'sheets/background_sheet.dart';
import 'sheets/look_sheet.dart';

/// ⏮ −1f ▶ +1f ⏭, and the two look pills — "2D", "Black" — that open
/// 5.2 and 5.3 (3.1).
class TransportBar extends ConsumerWidget {
  const TransportBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final playing = ref.watch(playbackControllerProvider.select((s) => s.playing));
    final playback = ref.read(playbackControllerProvider.notifier);
    final settings = ref.watch(projectControllerProvider.select((s) => s.settings));

    return Row(
      children: [
        _TransportButton(icon: Icons.skip_previous_rounded, tooltip: 'To head', width: 36, onTap: playback.toHead),
        _TransportButton(label: '−1f', tooltip: 'Back one frame', onTap: playback.stepBack),
        Tooltip(
          message: playing ? 'Pause' : 'Play',
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              width: 50,
              height: 50,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: p.primary, boxShadow: p.primaryShadow),
              child: InkWell(
                onTap: playback.togglePlay,
                child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: p.onInk, size: 22),
              ),
            ),
          ),
        ),
        _TransportButton(label: '+1f', tooltip: 'Forward one frame', onTap: playback.stepForward),
        _TransportButton(icon: Icons.skip_next_rounded, tooltip: 'To tail', width: 36, onTap: playback.toTail),
        const Spacer(),
        LookPill(
          label: settings.look == RollLook.flat2d ? '2D' : '3D',
          onTap: () => showEcSheet<void>(context, builder: (_) => const LookSheet()),
        ),
        const SizedBox(width: 6),
        LookPill(
          label: backgroundLabel(settings.background),
          onTap: () => showEcSheet<void>(context, builder: (_) => const BackgroundSheet()),
        ),
      ],
    );
  }
}

String backgroundLabel(MonitorBackground bg) => switch (bg) {
      MonitorBackground.black => 'Black',
      MonitorBackground.alpha => 'Alpha',
      MonitorBackground.green => 'Green',
      MonitorBackground.underlay => 'Underlay',
      MonitorBackground.custom => 'Colour',
    };

class _TransportButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String tooltip;
  final double width;
  final VoidCallback onTap;

  const _TransportButton({this.icon, this.label, required this.tooltip, this.width = 40, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          width: width,
          height: 44,
          child: Center(
            child: icon != null
                ? Icon(icon, size: 18, color: p.ink2)
                : Text(label!, style: context.type.mono.copyWith(fontSize: 11, color: p.ink2)),
          ),
        ),
      ),
    );
  }
}

/// A 32 px glass pill that opens a look setting.
class LookPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const LookPill({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = BorderRadius.circular(EcRadius.pill);
    return Material(
      type: MaterialType.transparency,
      borderRadius: shape,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        height: 32,
        decoration: BoxDecoration(color: p.glass, borderRadius: shape, border: Border.all(color: p.glassEdge)),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              widthFactor: 1,
              child: Text(label, style: context.type.bodyS.copyWith(fontSize: 11.5, fontWeight: FontWeight.w500, color: p.ink)),
            ),
          ),
        ),
      ),
    );
  }
}
