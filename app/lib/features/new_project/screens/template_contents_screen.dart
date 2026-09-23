import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_fields.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_settings.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../core/utils/formatting.dart';
import '../../../data/repositories/template_repository.dart';
import '../controllers/new_project_controller.dart';
import 'canvas_screen.dart';

/// 2.2 — what a template includes, before anything is created.
///
/// Templates come preloaded but nothing is forced: untick sections here, or
/// swipe a block away in the editor later. The first ten sections are
/// listed; the rest fold into "+ N more" with their own count.
class TemplateContentsScreen extends ConsumerStatefulWidget {
  final ProjectTemplate template;

  const TemplateContentsScreen({super.key, required this.template});

  @override
  ConsumerState<TemplateContentsScreen> createState() => _TemplateContentsScreenState();
}

class _TemplateContentsScreenState extends ConsumerState<TemplateContentsScreen> {
  static const _visible = 10;

  late final List<TemplateSection> _sections = ref.read(newProjectControllerProvider).sectionsOf(widget.template);
  late final Set<String> _included = {for (final s in _sections) if (s.includedByDefault) s.id};
  bool _expanded = false;

  void _toggle(String id, bool on) => setState(() => on ? _included.add(id) : _included.remove(id));

  void _continue() {
    ref.read(newProjectControllerProvider).createFromTemplate(widget.template, {..._included});
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CanvasScreen(step: '2 / 2')));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    final controller = ref.read(newProjectControllerProvider);
    final blockCount = controller.blockCountFor(widget.template, _included);
    final allOn = _included.length == _sections.length;

    final head = _expanded ? _sections : _sections.take(_visible).toList();
    final rest = _sections.skip(_visible).toList();
    final restOn = rest.where((s) => _included.contains(s.id)).length;

    return EcScaffold(
      topBar: EcTopBar(trailing: Text('1 / 2', style: t.mono.copyWith(fontSize: 10))),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: EcButton(
          label: 'Continue with ${plural(blockCount, 'block')}',
          onPressed: blockCount == 0 ? null : _continue,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EcEyebrow('${widget.template.name} template'),
                const SizedBox(height: 8),
                EcHeadline('What’s', emphasis: 'included', style: t.displayL.copyWith(fontSize: 38)),
                const SizedBox(height: 8),
                Text(
                  'Untick anything you don’t need. Blocks can be removed or added back any time in the editor.',
                  style: t.bodyS.copyWith(color: p.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('${_included.length} of ${_sections.length} selected',
                      style: t.mono.copyWith(fontSize: 10.5, color: p.ink2)),
                ),
                EcButton.text(
                  label: allOn ? 'Clear all' : 'Select all',
                  size: EcButtonSize.small,
                  onPressed: () => setState(() {
                    if (allOn) {
                      _included.clear();
                    } else {
                      _included.addAll(_sections.map((s) => s.id));
                    }
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          EcGroup(children: [
            for (final section in head)
              _SectionRow(section: section, included: _included.contains(section.id), onChanged: (v) => _toggle(section.id, v)),
            if (rest.isNotEmpty && !_expanded)
              EcGroupRow(
                title: '+ ${rest.length} more · ${restOn == rest.length ? 'all selected' : '$restOn selected'}',
                trailing: Icon(Icons.expand_more_rounded, color: p.faint),
                onTap: () => setState(() => _expanded = true),
              ),
          ]),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final TemplateSection section;
  final bool included;
  final ValueChanged<bool> onChanged;

  const _SectionRow({required this.section, required this.included, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: included ? 1 : 0.62,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: EcCheckbox(
          value: included,
          onChanged: onChanged,
          label: Row(
            children: [
              SizedBox(width: 38, child: Text(section.kind.code, style: t.mono.copyWith(fontSize: 9.5))),
              Expanded(child: Text(section.label, style: t.row.copyWith(fontSize: 14))),
            ],
          ),
        ),
      ),
    );
  }
}
