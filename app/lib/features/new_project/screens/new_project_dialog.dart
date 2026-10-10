import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/layout/layout_class.dart';
import '../../../core/theme/ec_type.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_chip.dart';
import '../../../core/widgets/ec_credit_frame.dart';
import '../../../core/widgets/ec_dialog.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../domain/models/canvas_format.dart';
import '../../../domain/models/user_profile.dart';
import '../../project/controllers/project_controller.dart';
import '../../project/project_navigation.dart';
import '../controllers/new_project_controller.dart';
import 'new_project_sheet.dart';

/// T2.1 / D10 — the phone's three steps (2.1 → 2.2 → 2.3) as one dialog:
/// template on the left, name, canvas and frame rate on the right, so the
/// whole decision is visible at once and there is no Next. A crash
/// recovery stays on top, the most urgent choice. The project name is
/// focused on open.
///
/// A template starts with its default sections (the phone's 2.2 choice);
/// everything here can change later in Timing & look.
class NewProjectDialog extends ConsumerStatefulWidget {
  final String slotLabel;
  const NewProjectDialog({super.key, required this.slotLabel});

  static Future<void> show(BuildContext context, {required String slotLabel}) =>
      showEcDialog<void>(context, builder: (_) => NewProjectDialog(slotLabel: slotLabel));

  @override
  ConsumerState<NewProjectDialog> createState() => _NewProjectDialogState();
}

/// The aspect ratios the design offers, in its order.
const _formats = ['239', '185', '16x9', '9x16'];
const _frameRates = <double>[23.976, 24, 25, 30];

class _NewProjectDialogState extends ConsumerState<NewProjectDialog> {
  ProjectTemplate? _template = kProjectTemplates.first;
  late final _name = TextEditingController(text: kProjectTemplates.first.defaultTitle);
  late String _formatId = kProjectTemplates.first.formatId;
  late double _fps = kProjectTemplates.first.fps;
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _pick(ProjectTemplate? template) {
    final prefs = (ref.read(userProfileProvider).value ?? const UserProfile()).preferences;
    setState(() {
      _template = template;
      _name.text = template?.defaultTitle ?? 'Untitled project';
      _formatId = template?.formatId ?? prefs.defaultFormatId;
      _fps = template?.fps ?? prefs.defaultFps;
    });
  }

  Future<void> _create() async {
    final newProject = ref.read(newProjectControllerProvider);
    final project = ref.read(projectControllerProvider.notifier);
    final navigator = Navigator.of(context);
    setState(() => _creating = true);
    if (!await newProject.canStart()) {
      // The plan's cap is checked before anything is made, as on the phone.
      if (mounted) setState(() => _creating = false);
      navigator.pop();
      return;
    }
    final template = _template;
    if (template == null) {
      await newProject.createEmpty();
    } else {
      newProject.createFromTemplate(template, newProject.defaultSectionsOf(template));
    }
    project
      ..setFormat(_formatId)
      ..setFps(_fps);
    final title = _name.text.trim();
    if (title.isNotEmpty) project.renameProject(title);
    navigator.pop();
    final host = navigator.context;
    if (host.mounted) await enterEditor(host);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final desktop = context.layoutClass == LayoutClass.expanded;
    final recovery = ref.watch(recoveryCandidateProvider).value;
    final screen = MediaQuery.sizeOf(context);

    final templates = _TemplateGrid(selected: _template, onPick: _pick);
    final settings = _CanvasPanel(
      name: _name,
      formatId: _formatId,
      fps: _fps,
      template: _template,
      showBlocks: desktop,
      onFormat: (id) => setState(() => _formatId = id),
      onFps: (fps) => setState(() => _fps = fps),
      onCreate: desktop || _creating ? null : _create,
      creating: _creating,
    );

    return EcDialog(
      width: desktop ? 1060 : screen.width - 40,
      height: desktop ? 800 : screen.height - 40,
      color: context.palette.sheet,
      padding: EdgeInsets.zero,
      semanticLabel: 'New project',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 30, 28, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EcEyebrow('New project · ${widget.slotLabel}'),
                      const SizedBox(height: 6),
                      Semantics(
                        header: true,
                        child: EcHeadline(
                          'Pick a',
                          emphasis: 'starting point.',
                          style: t.displayL.copyWith(fontSize: 40),
                        ),
                      ),
                    ],
                  ),
                ),
                EcCircleButton.surface(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (recovery != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
              child: RecoveryCard(summary: recovery),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: templates),
                  ),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: desktop ? 360 : 380,
                    child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 24), child: settings),
                  ),
                ],
              ),
            ),
          ),
          if (desktop)
            Container(
              padding: const EdgeInsets.fromLTRB(32, 16, 28, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.palette.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Everything here can change later in Timing & look.',
                      style: t.bodyS.copyWith(color: context.palette.ink2),
                    ),
                  ),
                  EcButton.secondary(
                    label: 'Cancel',
                    size: EcButtonSize.medium,
                    expand: false,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  EcButton(
                    label: 'Create project',
                    size: EcButtonSize.medium,
                    expand: false,
                    busy: _creating,
                    onPressed: _creating ? null : _create,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TemplateGrid extends ConsumerWidget {
  final ProjectTemplate? selected;
  final ValueChanged<ProjectTemplate?> onPick;
  const _TemplateGrid({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(newProjectControllerProvider);
    final cards = [
      for (final template in kProjectTemplates)
        _TemplateCard(
          name: template.name,
          description: template.description,
          meta:
              '${formatFps(template.fps)} · ${CanvasFormat.byId(template.formatId).aspect} · '
              '${plural(controller.blockCountOf(template), 'block')}',
          preview: _preview(template),
          selected: selected?.id == template.id,
          onTap: () => onPick(template),
        ),
      _TemplateCard(
        name: 'Start empty',
        description: 'A blank roll at your project defaults.',
        meta: 'Your defaults · 0 blocks',
        preview: const ('', ['—']),
        selected: selected == null,
        onTap: () => onPick(null),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 480 ? 2 : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(width: (constraints.maxWidth - 12 * (columns - 1)) / columns, child: card),
          ],
        );
      },
    );
  }

  /// A stand-in credit for each template, as its first card would read.
  (String, List<String>) _preview(ProjectTemplate template) => switch (template.id) {
    'short' => ('Cast', ['A. Performer']),
    'social' || 'vertical' => ('Made by', ['A. Creator']),
    _ => ('Directed by', ['A. Director']),
  };
}

class _TemplateCard extends StatelessWidget {
  final String name;
  final String description;
  final String meta;
  final (String, List<String>) preview;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.name,
    required this.description,
    required this.meta,
    required this.preview,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final shape = BorderRadius.circular(18);
    return Semantics(
      selected: selected,
      button: true,
      label: name,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: shape,
          border: Border.all(color: selected ? p.accentSolid : p.line, width: selected ? 1.5 : 1),
          boxShadow: selected ? [BoxShadow(color: p.accentWash, spreadRadius: 4)] : p.rowShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EcCreditFrame(
                    height: 132,
                    child: preview.$1.isEmpty
                        ? Text('—', style: t.titleM.copyWith(color: Colors.white))
                        : CreditCard(header: preview.$1, names: preview.$2, nameSize: 15),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 10, 4, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: t.titleM.copyWith(fontSize: 15)),
                              const SizedBox(height: 3),
                              Text(description, style: t.caption.copyWith(fontSize: 12)),
                              const SizedBox(height: 5),
                              Text(meta, style: t.mono.copyWith(fontSize: 10)),
                            ],
                          ),
                        ),
                        if (selected)
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(gradient: p.primary, shape: BoxShape.circle),
                            child: Icon(Icons.check_rounded, size: 14, color: p.onInk),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CanvasPanel extends ConsumerWidget {
  final TextEditingController name;
  final String formatId;
  final double fps;
  final ProjectTemplate? template;
  final bool showBlocks;
  final ValueChanged<String> onFormat;
  final ValueChanged<double> onFps;

  /// The tablet's own Create button; null on the desktop, whose footer has it.
  final VoidCallback? onCreate;
  final bool creating;

  const _CanvasPanel({
    required this.name,
    required this.formatId,
    required this.fps,
    required this.template,
    required this.showBlocks,
    required this.onFormat,
    required this.onFps,
    required this.onCreate,
    required this.creating,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final format = CanvasFormat.byId(formatId);
    final kinds = template == null ? const [] : ref.read(newProjectControllerProvider).blockKindsOf(template!);
    final label = t.label.copyWith(color: p.ink);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Project name', style: label),
          const SizedBox(height: 7),
          TextField(
            controller: name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: t.bodyL,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: p.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.line2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: p.accentSolid, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Aspect ratio', style: label),
          const SizedBox(height: 7),
          EcSegmented(
            labels: [for (final id in _formats) CanvasFormat.byId(id).aspect],
            selectedIndex: _formats.indexOf(formatId).clamp(0, _formats.length - 1),
            onChanged: (i) => onFormat(_formats[i]),
          ),
          const SizedBox(height: 7),
          Text('Canvas ${format.w} × ${format.h}', style: t.mono.copyWith(fontSize: 10.5)),
          const SizedBox(height: 16),
          Text('Frame rate', style: label),
          const SizedBox(height: 7),
          Row(
            children: [
              for (final (i, rate) in _frameRates.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: EcChip(
                    label: formatFpsShort(rate),
                    mono: true,
                    height: 40,
                    selected: (rate - fps).abs() < .001,
                    onTap: () => onFps(rate),
                  ),
                ),
              ],
            ],
          ),
          if (showBlocks && kinds.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: p.line),
            const SizedBox(height: 14),
            Text(caps('Starts with ${plural(kinds.length, 'block')}'), style: t.eyebrow.copyWith(fontSize: 9.5)),
            const SizedBox(height: 8),
            Wrap(spacing: 5, runSpacing: 5, children: [for (final kind in kinds) EcCodeTile(kind.code, size: 28)]),
          ],
          if (onCreate != null || creating) ...[
            const SizedBox(height: 18),
            EcButton(label: 'Create project', busy: creating, onPressed: onCreate),
          ],
        ],
      ),
    );
  }
}

/// "24", "23.976" — a rate as a chip shows it.
String formatFpsShort(double fps) => fps == fps.roundToDouble() ? fps.toStringAsFixed(0) : fps.toString();
