import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_chip.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../domain/models/canvas_format.dart';
import '../../project/controllers/project_controller.dart';
import '../../project/project_navigation.dart';

/// 2.3 — the canvas and the frame rate: the two facts timing depends on.
///
/// Frame rate is set with the project, not at export, because it decides
/// which scroll speeds can run without judder. The canvas is independent of
/// how the phone is held.
class CanvasScreen extends ConsumerStatefulWidget {
  /// "2 / 2" after the template contents; empty for "Start empty", where
  /// this is the only step.
  final String step;

  const CanvasScreen({super.key, this.step = ''});

  @override
  ConsumerState<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends ConsumerState<CanvasScreen> {
  late final _customW = TextEditingController(text: '${ref.read(projectControllerProvider).settings.customW}');
  late final _customH = TextEditingController(text: '${ref.read(projectControllerProvider).settings.customH}');
  bool _opening = false;

  @override
  void dispose() {
    _customW.dispose();
    _customH.dispose();
    super.dispose();
  }

  void _useCustom() {
    final w = int.tryParse(_customW.text);
    final h = int.tryParse(_customH.text);
    if (w == null || h == null || w < 16 || h < 16) return;
    FocusScope.of(context).unfocus();
    ref.read(projectControllerProvider.notifier).applyCustomSize(w, h);
  }

  Future<void> _open() async {
    setState(() => _opening = true);
    await enterEditor(context, replaceFlow: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    final settings = ref.watch(projectControllerProvider.select((s) => s.settings));
    final controller = ref.read(projectControllerProvider.notifier);

    return EcScaffold(
      topBar: null,
      scrollable: false,
      padding: EdgeInsets.zero,
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: EcButton(label: 'Open editor', busy: _opening, onPressed: _opening ? null : _open),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                EcCircleButton.glass(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Canvas', style: t.displayM),
                      const SizedBox(height: 3),
                      Text('Independent of how you hold the phone', style: t.caption),
                    ],
                  ),
                ),
                if (widget.step.isNotEmpty) Text(widget.step, style: t.mono.copyWith(fontSize: 10)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.45,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final format in CanvasFormat.picker)
                      _FormatTile(
                        format: format,
                        selected: settings.formatId == format.id,
                        onTap: () => controller.setFormat(format.id),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                EcSectionLabel(settings.formatId == CanvasFormat.customId ? 'Custom · in use' : 'Custom'),
                Row(
                  children: [
                    Expanded(child: _SizeField(controller: _customW, label: 'Width')),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('×', style: t.body.copyWith(color: p.muted)),
                    ),
                    Expanded(child: _SizeField(controller: _customH, label: 'Height')),
                    const SizedBox(width: 8),
                    EcButton(label: 'Use', variant: EcButtonVariant.secondary, size: EcButtonSize.medium, onPressed: _useCustom),
                  ],
                ),
                const SizedBox(height: 18),
                const EcSectionLabel('Frame rate · part of the project'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final fps in kFrameRates)
                      EcChip(
                        label: fps == fps.roundToDouble() ? fps.toStringAsFixed(0) : '$fps',
                        mono: true,
                        filled: true,
                        height: 38,
                        selected: settings.fps == fps,
                        onTap: () => controller.setFps(fps),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  final CanvasFormat format;
  final bool selected;
  final VoidCallback onTap;

  const _FormatTile({required this.format, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    // The frame preview keeps the real ratio inside a 96 × 44 box.
    final scale = [96 / format.w, 44 / format.h].reduce((a, b) => a < b ? a : b);
    final shape = BorderRadius.circular(EcRadius.row);
    return Semantics(
      selected: selected,
      button: true,
      label: '${format.label}, ${format.sub}',
      child: AnimatedContainer(
        duration: EcMotion.fast,
        decoration: BoxDecoration(
          color: selected ? p.surface : p.glass,
          borderRadius: shape,
          border: Border.all(color: selected ? p.accentSolid : p.glassEdge, width: selected ? 1.5 : 1),
          boxShadow: selected ? [BoxShadow(color: p.accentWash, spreadRadius: 4)] : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 44,
                    child: Center(
                      child: Container(
                        width: format.w * scale,
                        height: format.h * scale,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: p.monitor, borderRadius: BorderRadius.circular(4)),
                        child: format.id == 'uhd'
                            ? Text('4K', style: t.pill.copyWith(fontSize: 8, color: Colors.white.withValues(alpha: .6)))
                            : null,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(format.label, style: t.titleS.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(format.sub, style: t.mono.copyWith(fontSize: 10)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _SizeField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: label,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.line2),
          borderRadius: BorderRadius.circular(EcRadius.inner),
        ),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
          style: context.type.monoM,
          decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
        ),
      ),
    );
  }
}
