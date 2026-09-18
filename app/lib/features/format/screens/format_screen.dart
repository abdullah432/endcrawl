import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_chip.dart';
import '../../editor/screens/editor_screen.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../project/controllers/project_controller.dart';
import '../../../domain/models/canvas_format.dart';
import '../widgets/format_card.dart';

/// Screen 2: a dedicated format step, not buried in settings (§4 of the
/// brief). Canvas orientation is chosen here, independent of how the user
/// is holding the phone; frame rate is part of the project, not the
/// export dialog.
class FormatScreen extends ConsumerStatefulWidget {
  const FormatScreen({super.key});

  @override
  ConsumerState<FormatScreen> createState() => _FormatScreenState();
}

class _FormatScreenState extends ConsumerState<FormatScreen> {
  late final TextEditingController _wCtrl;
  late final TextEditingController _hCtrl;

  @override
  void initState() {
    super.initState();
    final s = ref.read(projectControllerProvider).settings;
    _wCtrl = TextEditingController(text: s.customW.toString());
    _hCtrl = TextEditingController(text: s.customH.toString());
  }

  @override
  void dispose() {
    _wCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(projectControllerProvider.select((s) => s.settings));
    final controller = ref.read(projectControllerProvider.notifier);

    return Scaffold(
      backgroundColor: EcColors.surfaceCanvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(EcSpace.s4),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(EcRadius.full),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(color: EcColors.surfaceRaised, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icon(Icons.chevron_left, color: EcColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: EcSpace.s3),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Canvas format', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: EcColors.textPrimary)),
                        Text(
                          'Independent of how you hold the phone',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: EcColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(EcSpace.s4, 0, EcSpace.s4, EcSpace.s6),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: EcSpace.s3,
                    crossAxisSpacing: EcSpace.s3,
                    childAspectRatio: 1.15,
                    children: [
                      for (final f in CanvasFormat.presets)
                        FormatCard(
                          format: f,
                          selected: settings.formatId == f.id,
                          onTap: () => controller.setFormat(f.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: EcSpace.s5),
                  const Text('CUSTOM', style: TextStyle(fontSize: 11, letterSpacing: 2, color: EcColors.textTertiary)),
                  const SizedBox(height: EcSpace.s2),
                  Row(
                    children: [
                      Expanded(child: _sizeField(_wCtrl)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: EcSpace.s2),
                        child: Text('×', style: TextStyle(color: EcColors.textTertiary)),
                      ),
                      Expanded(child: _sizeField(_hCtrl)),
                      const SizedBox(width: EcSpace.s2),
                      OutlinedButton(
                        onPressed: () {
                          final w = int.tryParse(_wCtrl.text) ?? settings.customW;
                          final h = int.tryParse(_hCtrl.text) ?? settings.customH;
                          controller.applyCustomSize(w, h);
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          foregroundColor: EcColors.textSecondary,
                          side: const BorderSide(color: EcColors.borderStrong),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)),
                        ),
                        child: const Text('Use', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: EcSpace.s5),
                  const Text('FRAME RATE · PART OF THE PROJECT', style: TextStyle(fontSize: 11, letterSpacing: 2, color: EcColors.textTertiary)),
                  const SizedBox(height: EcSpace.s2),
                  Wrap(
                    spacing: EcSpace.s2,
                    runSpacing: EcSpace.s2,
                    children: [
                      for (final v in kFrameRates)
                        EcChip(
                          label: v.toString(),
                          mono: true,
                          selected: settings.fps == v,
                          onTap: () => controller.setFps(v),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(EcSpace.s4, EcSpace.s3, EcSpace.s4, EcSpace.s3),
        child: FilledButton(
          onPressed: () async {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
            ref.read(playbackControllerProvider.notifier).resetToHead();
            // First write of a brand-new project: this is the point the
            // document becomes real and enters the library.
            await ref.read(projectControllerProvider.notifier).markOpened();
            if (!context.mounted) return;
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditorScreen()));
          },
          style: FilledButton.styleFrom(
            backgroundColor: EcColors.accentPrimary,
            foregroundColor: EcColors.accentInk,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          child: const Text('Open editor'),
        ),
      ),
    );
  }

  Widget _sizeField(TextEditingController c) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 14, color: EcColors.textPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: EcColors.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: EcSpace.s3, vertical: EcSpace.s3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(EcRadius.md), borderSide: const BorderSide(color: EcColors.borderHairline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(EcRadius.md), borderSide: const BorderSide(color: EcColors.borderHairline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(EcRadius.md), borderSide: const BorderSide(color: EcColors.accentPrimary)),
      ),
    );
  }
}
