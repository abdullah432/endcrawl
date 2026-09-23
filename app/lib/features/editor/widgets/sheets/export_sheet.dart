import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/ec_chip.dart';
import '../../../../core/widgets/ec_sheet.dart';
import '../../../export/controllers/export_controller.dart';
import '../../../export/models/export_models.dart';
import '../../../project/controllers/project_controller.dart';
import '../../../../domain/engine/roll_engine.dart';
import '../../controllers/editor_ui_controller.dart';

/// The export sheet, designed as a confidence-building screen (§9 of the
/// brief): restated, non-editable settings; codec choices with alpha
/// called out; a resolution ladder; and a progress state with a real
/// failure/resume case. This build is UI/UX fidelity only — there is no
/// real encoder, so progress here is simulated exactly like the prototype.
class ExportSheet extends ConsumerWidget {
  const ExportSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectControllerProvider);
    final exportState = ref.watch(exportControllerProvider);
    final exportCtrl = ref.read(exportControllerProvider.notifier);
    final e = project.engine;
    final secs = e.fps == 0 ? 0.0 : e.totalFrames / e.fps;
    final scaleF = exportState.resolution.scaleFactor(project.formatW);
    final sizeMB = (secs * exportState.codec.simulatedMbps * scaleF * scaleF / 8 * 10).round() / 10;
    final run = exportState.run;

    Widget body;
    if (run == null) {
      body = _idle(context, ref, project, exportCtrl, exportState, e, secs, sizeMB);
    } else if (run.phase == ExportPhase.running) {
      body = _running(project, exportCtrl, exportState, run);
    } else if (run.phase == ExportPhase.failed) {
      body = _failed(exportCtrl, project);
    } else {
      body = _done(context, exportState, sizeMB, e);
    }

    return EcSheet(title: 'Export', child: body);
  }

  Widget _idle(BuildContext context, WidgetRef ref, ProjectState project, ExportController ctrl, ExportState state, RollEngineResult e, double secs, double sizeMB) {
    final formatLabel = project.settings.format.label;
    final facts = [
      ('Format', formatLabel),
      ('Frame rate', '${project.settings.fps} fps'),
      ('Runtime', formatTimecode(e.totalFrames, e.fps)),
      ('Scroll', '${e.ppf.toStringAsFixed(2)} px/f'),
    ];
    final renderEst = '${(secs * (state.codec == Codec.prores ? .9 : .35)).clamp(1, double.infinity).round()} s · $sizeMB MB';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(EcSpace.s3),
          decoration: BoxDecoration(color: EcColors.surfaceRaised, border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.lg)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('LOCKED FOR THIS RENDER', style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, color: EcColors.textTertiary)),
                  TextButton(
                    onPressed: () => ref.read(editorUiControllerProvider.notifier).openSheet(EditorSheet.duration),
                    style: TextButton.styleFrom(minimumSize: Size.zero, padding: EdgeInsets.zero),
                    child: const Text('Edit', style: TextStyle(fontSize: 11.5, color: EcColors.accentPrimary)),
                  ),
                ],
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 3.4,
                children: [
                  for (final f in facts)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.$1, style: const TextStyle(fontSize: 10, color: EcColors.textTertiary)),
                        Text(f.$2, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 12.5, color: EcColors.textPrimary)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: EcSpace.s4),
        const EcSectionLabel('Codec'),
        for (final c in Codec.values)
          Padding(
            padding: const EdgeInsets.only(bottom: EcSpace.s2),
            child: Material(
              color: state.codec == c ? EcColors.accentWash : EcColors.surfaceRaised,
              borderRadius: BorderRadius.circular(EcRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(EcRadius.md),
                onTap: () => ctrl.setCodec(c),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.all(EcSpace.s3),
                  decoration: BoxDecoration(border: Border.all(color: state.codec == c ? EcColors.accentPrimary : EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.md)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(c.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: EcColors.textPrimary)),
                              if (c.hasAlpha)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(border: Border.all(color: EcColors.accentDim), borderRadius: BorderRadius.circular(EcRadius.sm)),
                                  child: const Text('ALPHA', style: TextStyle(fontSize: 9, letterSpacing: 1, color: EcColors.accentPrimary)),
                                ),
                            ]),
                            const SizedBox(height: 2),
                            Text(c.description, style: const TextStyle(fontSize: 11, color: EcColors.textTertiary)),
                          ],
                        ),
                      ),
                      Text('${(secs * c.simulatedMbps * scaleFCache(project, state) * scaleFCache(project, state) / 8).round()} MB', style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 11, color: EcColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: EcSpace.s2),
        const EcSectionLabel('Resolution'),
        Row(
          children: [
            for (final r in ExportResolution.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: EcSpace.s2),
                  child: EcChip(label: r.label(project.formatW), selected: state.resolution == r, onTap: () => ctrl.setResolution(r)),
                ),
              ),
          ],
        ),
        const SizedBox(height: EcSpace.s3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Estimated render', style: TextStyle(fontSize: 11.5, color: EcColors.textSecondary)),
            Flexible(
              child: Text(
                renderEst,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 11.5, color: EcColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: EcSpace.s3),
        FilledButton(
          onPressed: () => ctrl.start(sourceWidth: project.formatW),
          style: FilledButton.styleFrom(backgroundColor: EcColors.accentPrimary, foregroundColor: EcColors.accentInk, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          child: Text('Render ${state.codec.label}'),
        ),
      ],
    );
  }

  double scaleFCache(ProjectState project, ExportState state) => state.resolution.scaleFactor(project.formatW);

  Widget _running(ProjectState project, ExportController ctrl, ExportState state, ExportRun run) {
    final e = project.engine;
    final frame = (e.totalFrames * run.pct / 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.black, border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.sm)),
              child: Text(project.name, textAlign: TextAlign.center, style: const TextStyle(fontFamily: EcFonts.archivoNarrow, fontSize: 7, letterSpacing: 2, color: Colors.white70)),
            ),
            const SizedBox(width: EcSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rendering ${state.codec.label}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: EcColors.textPrimary)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(EcRadius.full),
                    child: LinearProgressIndicator(value: run.pct / 100, minHeight: 4, backgroundColor: EcColors.surfaceHi, valueColor: const AlwaysStoppedAnimation(EcColors.accentPrimary)),
                  ),
                  const SizedBox(height: 4),
                  Text('${run.pct.round()}% · frame $frame of ${e.totalFrames.round()}', style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 10.5, color: EcColors.textTertiary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: EcSpace.s4),
        Builder(builder: (context) {
          return OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), foregroundColor: EcColors.textSecondary, side: const BorderSide(color: EcColors.borderStrong), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md))),
            child: const Text('Keep working — render continues in the background', style: TextStyle(fontSize: 13)),
          );
        }),
      ],
    );
  }

  Widget _failed(ExportController ctrl, ProjectState project) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(EcSpace.s4),
          decoration: BoxDecoration(color: EcColors.warnWash, border: Border.all(color: EcColors.warn.withValues(alpha: .45)), borderRadius: BorderRadius.circular(EcRadius.lg)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Render stopped at 62%', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: EcColors.warn)),
              const SizedBox(height: 4),
              const Text(
                'Not enough free space for a 1.4 GB file. Free up space, or drop to 1080p and try again — the first 62% is cached, so the retry resumes.',
                style: TextStyle(fontSize: 12, color: EcColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: EcSpace.s3),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () => ctrl.start(sourceWidth: project.formatW),
                style: FilledButton.styleFrom(backgroundColor: EcColors.accentPrimary, foregroundColor: EcColors.accentInk, minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md))),
                child: const Text('Resume', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: EcSpace.s2),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ctrl.setResolution(ExportResolution.hd);
                  ctrl.editSettings();
                },
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: EcColors.textSecondary, side: const BorderSide(color: EcColors.borderStrong), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md))),
                child: const Text('Lower resolution', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _done(BuildContext context, ExportState state, double sizeMB, RollEngineResult e) {
    const destinations = ['Save to Files', 'Save to Photos', 'AirDrop', 'Share sheet…'];
    return Column(
      children: [
        Text('${state.codec.label} ready', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: EcColors.textPrimary)),
        const SizedBox(height: 4),
        Text('$sizeMB MB · ${formatTimecode(e.totalFrames, e.fps)}', style: const TextStyle(fontSize: 12, color: EcColors.textSecondary)),
        const SizedBox(height: EcSpace.s4),
        for (final d in destinations)
          Padding(
            padding: const EdgeInsets.only(bottom: EcSpace.s2),
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: EcColors.textPrimary, side: const BorderSide(color: EcColors.borderHairline), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md))),
              child: Text(d, style: const TextStyle(fontSize: 13.5)),
            ),
          ),
      ],
    );
  }
}
