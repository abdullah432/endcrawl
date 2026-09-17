import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/ec_stepper.dart';
import '../../../project/controllers/project_controller.dart';
import '../../../../domain/models/credit_block.dart';

/// The per-type field editor for every block type except cast (which gets
/// its own dedicated editor — see `cast_block_editor.dart`).
class GenericBlockEditor extends ConsumerWidget {
  final CreditBlock block;
  const GenericBlockEditor({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(projectControllerProvider.notifier);

    Widget textField(String label, String value, void Function(String) onChanged) {
      return Padding(
        padding: const EdgeInsets.only(bottom: EcSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 10.5, letterSpacing: 1.2, color: EcColors.textTertiary)),
            const SizedBox(height: 6),
            TextFormField(
              key: ValueKey('$label-${block.id}'),
              initialValue: value,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 14, color: EcColors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: EcColors.surfaceRaised,
                contentPadding: const EdgeInsets.symmetric(horizontal: EcSpace.s3, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(EcRadius.md), borderSide: const BorderSide(color: EcColors.borderHairline)),
              ),
            ),
          ],
        ),
      );
    }

    Widget linesField(String label, List<String> lines, void Function(List<String>) onChanged) {
      return Padding(
        padding: const EdgeInsets.only(bottom: EcSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 10.5, letterSpacing: 1.2, color: EcColors.textTertiary)),
            const SizedBox(height: 6),
            TextFormField(
              key: ValueKey('$label-${block.id}'),
              initialValue: lines.join('\n'),
              onChanged: (v) => onChanged(v.split('\n')),
              minLines: 4,
              maxLines: 8,
              style: const TextStyle(fontSize: 13, color: EcColors.textPrimary, height: 1.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: EcColors.surfaceRaised,
                contentPadding: const EdgeInsets.symmetric(horizontal: EcSpace.s3, vertical: EcSpace.s2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(EcRadius.md), borderSide: const BorderSide(color: EcColors.borderHairline)),
              ),
            ),
          ],
        ),
      );
    }

    Widget numField(String label, double value, double step, void Function(double) onChanged, {String unit = 's'}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: EcSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 10.5, letterSpacing: 1.2, color: EcColors.textTertiary)),
            const SizedBox(height: 6),
            EcStepper(
              display: '${value.toStringAsFixed(1)}$unit',
              onDec: () => onChanged((value - step).clamp(0, double.infinity)),
              onInc: () => onChanged(value + step),
            ),
          ],
        ),
      );
    }

    switch (block) {
      case TitleBlock v:
        return Column(children: [
          textField('Studio banner', v.banner, (t) => controller.patchBlock(v.id, (b) => (b as TitleBlock).copyWith(banner: t))),
          textField('Film title', v.title, (t) => controller.patchBlock(v.id, (b) => (b as TitleBlock).copyWith(title: t))),
          textField('Byline', v.byline, (t) => controller.patchBlock(v.id, (b) => (b as TitleBlock).copyWith(byline: t))),
          numField('Title size (× credit size)', v.titleScale, .1, (n) => controller.patchBlock(v.id, (b) => (b as TitleBlock).copyWith(titleScale: n)), unit: '×'),
        ]);
      case DeptBlock v:
        return Column(children: [
          textField('Header', v.header, (t) => controller.patchBlock(v.id, (b) => (b as DeptBlock).copyWith(header: t))),
          linesField('Names — one per line', v.names, (l) => controller.patchBlock(v.id, (b) => (b as DeptBlock).copyWith(names: l))),
        ]);
      case SongBlock v:
        return Column(children: [
          textField('Song', v.songTitle, (t) => controller.patchBlock(v.id, (b) => (b as SongBlock).copyWith(songTitle: t))),
          textField('Artist', v.artist, (t) => controller.patchBlock(v.id, (b) => (b as SongBlock).copyWith(artist: t))),
          textField('Courtesy of', v.courtesy, (t) => controller.patchBlock(v.id, (b) => (b as SongBlock).copyWith(courtesy: t))),
        ]);
      case ThanksBlock v:
        return Column(children: [
          textField('Header', v.header, (t) => controller.patchBlock(v.id, (b) => (b as ThanksBlock).copyWith(header: t))),
          linesField('Names — one per line', v.names, (l) => controller.patchBlock(v.id, (b) => (b as ThanksBlock).copyWith(names: l))),
        ]);
      case LogosBlock v:
        return linesField('Logos — one per line', v.logos, (l) => controller.patchBlock(v.id, (b) => (b as LogosBlock).copyWith(logos: l)));
      case HoldBlock v:
        return Column(children: [
          linesField('Card lines', v.lines, (l) => controller.patchBlock(v.id, (b) => (b as HoldBlock).copyWith(lines: l))),
          numField('Hold', v.hold, .5, (n) => controller.patchBlock(v.id, (b) => (b as HoldBlock).copyWith(hold: n))),
          numField('Fade in', v.fadeIn, .25, (n) => controller.patchBlock(v.id, (b) => (b as HoldBlock).copyWith(fadeIn: n))),
          numField('Fade out', v.fadeOut, .25, (n) => controller.patchBlock(v.id, (b) => (b as HoldBlock).copyWith(fadeOut: n))),
        ]);
      case SpacerBlock v:
        return numField('Gap', v.seconds, .25, (n) => controller.patchBlock(v.id, (b) => (b as SpacerBlock).copyWith(seconds: n)));
      case CastBlock():
        return const SizedBox.shrink();
    }
  }
}
