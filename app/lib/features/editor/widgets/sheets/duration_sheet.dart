import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/ec_chip.dart';
import '../../../../core/widgets/ec_sheet.dart';
import '../../../../core/widgets/ec_stepper.dart';
import '../../../project/controllers/project_controller.dart';
import '../../../../domain/models/project_settings.dart';
import '../../../../domain/engine/roll_engine.dart';
import '../../controllers/editor_ui_controller.dart';

/// Timing: the user types a target runtime and the engine derives the
/// scroll rate, or sets a readable scroll speed and the engine reports
/// the resulting runtime — both directions reachable in one tap of each
/// other (§3 of the brief).
class DurationSheet extends ConsumerStatefulWidget {
  const DurationSheet({super.key});

  @override
  ConsumerState<DurationSheet> createState() => _DurationSheetState();
}

class _DurationSheetState extends ConsumerState<DurationSheet> {
  late final TextEditingController _durText;

  @override
  void initState() {
    super.initState();
    final project = ref.read(projectControllerProvider);
    _durText = TextEditingController(text: formatTimecode(project.engine.totalFrames, project.engine.fps));
  }

  @override
  void dispose() {
    _durText.dispose();
    super.dispose();
  }

  void _applyText(String v, ProjectController controller, double fps) {
    final parts = v.split(':');
    if (parts.length != 4) return;
    final nums = parts.map((p) => int.tryParse(p)).toList();
    if (nums.any((n) => n == null)) return;
    final b = fps.round();
    final frames = (nums[0]! * 3600 + nums[1]! * 60 + nums[2]!) * b + nums[3]!;
    controller.setDurationFrames(frames);
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectControllerProvider);
    final controller = ref.read(projectControllerProvider.notifier);
    final settings = project.settings;
    final e = project.engine;
    final snaps = engineSnaps(e);

    return EcSheet(
      title: 'Timing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcSegmented(
            labels: const ['Lock runtime', 'Lock speed'],
            selectedIndex: settings.mode == TimingMode.duration ? 0 : 1,
            onChanged: (i) {
              if (i == 0) {
                controller.setModeDuration();
                _durText.text = formatTimecode(project.engine.totalFrames, project.engine.fps);
              } else {
                controller.setModeSpeed();
              }
            },
          ),
          const SizedBox(height: EcSpace.s4),
          Container(
            padding: const EdgeInsets.all(EcSpace.s4),
            decoration: BoxDecoration(color: EcColors.surfaceRaised, border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.lg)),
            child: settings.mode == TimingMode.duration
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EcSectionLabel('Target runtime'),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _durText,
                              onChanged: (v) => _applyText(v, controller, settings.fps),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'))],
                              style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 21, color: EcColors.textPrimary),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: EcColors.surfaceSunken,
                                contentPadding: const EdgeInsets.symmetric(horizontal: EcSpace.s3, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(EcRadius.md), borderSide: const BorderSide(color: EcColors.borderStrong)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(EcRadius.md), borderSide: const BorderSide(color: EcColors.borderStrong)),
                              ),
                            ),
                          ),
                          const SizedBox(width: EcSpace.s2),
                          Column(
                            children: [
                              _smallStep(Icons.add, () {
                                controller.durationUp();
                                _durText.text = formatTimecode(project.engine.totalFrames + settings.fps, e.fps);
                              }),
                              const SizedBox(height: 4),
                              _smallStep(Icons.remove, () {
                                controller.durationDown();
                                _durText.text = formatTimecode(project.engine.totalFrames - settings.fps, e.fps);
                              }),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: EcSpace.s2),
                      Text('Engine derives the scroll rate: ${e.ppf.toStringAsFixed(3)} px/frame · ${e.pps.round()} px/s',
                          style: const TextStyle(fontSize: 11, color: EcColors.textTertiary)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EcSectionLabel('Scroll speed'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(e.ppf.clamp(1, double.infinity).round().toString(), style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 30, color: EcColors.accentPrimary)),
                          const SizedBox(width: EcSpace.s2),
                          Text('px / frame at ${project.formatW}×${project.formatH}', style: const TextStyle(fontSize: 12, color: EcColors.textSecondary)),
                        ],
                      ),
                      Slider(
                        value: settings.ppf.clamp(1, 14),
                        min: 1,
                        max: 14,
                        divisions: 13,
                        onChanged: (v) => controller.setPpf(v),
                      ),
                      Text('Engine derives the runtime: ${formatTimecode(e.totalFrames, e.fps)}', style: const TextStyle(fontSize: 11, color: EcColors.textTertiary)),
                    ],
                  ),
          ),
          const SizedBox(height: EcSpace.s4),
          Row(
            children: [
              Expanded(child: _statusCard(title: e.clean ? 'Judder-free' : 'Fractional rate', detail: '${e.ppf.toStringAsFixed(3)} px per frame at ${settings.fps} fps', good: e.clean)),
              const SizedBox(width: EcSpace.s2),
              Expanded(child: _statusCard(title: e.readable ? 'Readable' : 'Too fast', detail: 'a line stays on screen ${e.dwellSeconds.toStringAsFixed(1)}s · floor 3.0s', good: e.readable)),
            ],
          ),
          if (!e.clean && snaps.isNotEmpty) ...[
            const SizedBox(height: EcSpace.s4),
            const Text('Nearest whole-pixel rates — one tap, no judder:', style: TextStyle(fontSize: 11, color: EcColors.textSecondary)),
            const SizedBox(height: EcSpace.s2),
            Row(
              children: [
                for (final s in snaps)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: EcSpace.s2),
                      child: Material(
                        color: EcColors.accentWash,
                        borderRadius: BorderRadius.circular(EcRadius.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(EcRadius.md),
                          onTap: () {
                            controller.applySnap(s.$1);
                            ref.read(editorUiControllerProvider.notifier).resetWarn();
                            _durText.text = formatTimecode(s.$2, e.fps);
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 56),
                            padding: const EdgeInsets.all(EcSpace.s2),
                            decoration: BoxDecoration(border: Border.all(color: EcColors.accentDim), borderRadius: BorderRadius.circular(EcRadius.md)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(formatTimecode(s.$2, e.fps), style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 14, color: EcColors.accentPrimary)),
                                Text('${s.$1} px/frame', style: const TextStyle(fontSize: 10.5, color: EcColors.textTertiary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: EcSpace.s4),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(EcSpace.s3),
                  decoration: BoxDecoration(color: EcColors.surfaceRaised, border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.md)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Head black', style: TextStyle(fontSize: 11, color: EcColors.textSecondary)),
                      const SizedBox(height: 6),
                      EcStepper(display: '${settings.headSeconds.toStringAsFixed(1)}s', onDec: controller.headDown, onInc: controller.headUp),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: EcSpace.s2),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(EcSpace.s3),
                  decoration: BoxDecoration(color: EcColors.surfaceRaised, border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.md)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tail black', style: TextStyle(fontSize: 11, color: EcColors.textSecondary)),
                      const SizedBox(height: 6),
                      EcStepper(display: '${settings.tailSeconds.toStringAsFixed(1)}s', onDec: controller.tailDown, onInc: controller.tailUp),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallStep(IconData icon, VoidCallback onTap) {
    return Material(
      color: EcColors.surfaceHi,
      borderRadius: BorderRadius.circular(EcRadius.sm),
      child: InkWell(borderRadius: BorderRadius.circular(EcRadius.sm), onTap: onTap, child: SizedBox(width: 46, height: 25, child: Icon(icon, size: 13, color: EcColors.textPrimary))),
    );
  }

  Widget _statusCard({required String title, required String detail, required bool good}) {
    final fg = good ? EcColors.accentPrimary : EcColors.warn;
    return Container(
      padding: const EdgeInsets.all(EcSpace.s3),
      decoration: BoxDecoration(
        color: good ? EcColors.accentWash : EcColors.warnWash,
        border: Border.all(color: good ? EcColors.accentDim : EcColors.warn.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(EcRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg))),
          ]),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 10.5, color: EcColors.textTertiary, height: 1.35)),
        ],
      ),
    );
  }
}
