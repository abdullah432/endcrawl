import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_fields.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../domain/models/project.dart';

/// 1.4 — renaming a project.
///
/// The name arrives selected with the keyboard up, and the helper says why
/// the name matters: it becomes the file name of every render.
class RenameSheet extends StatefulWidget {
  final String current;

  const RenameSheet({super.key, required this.current});

  /// Returns the new name, or null if cancelled or unchanged.
  static Future<String?> show(BuildContext context, String current) {
    return showEcSheet<String>(context, builder: (_) => RenameSheet(current: current));
  }

  @override
  State<RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<RenameSheet> {
  late final _controller = TextEditingController(text: widget.current)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.current.length);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _valid {
    final clean = sanitizeProjectTitle(_controller.text);
    return clean == null || clean == widget.current ? null : clean;
  }

  void _save() {
    final value = _valid;
    if (value != null) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return EcSheet(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        child: Row(
          children: [
            EcButton(
              label: 'Cancel',
              variant: EcButtonVariant.plain,
              size: EcButtonSize.small,
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(child: Text('Rename', textAlign: TextAlign.center, style: t.displayS.copyWith(fontSize: 24))),
            EcButton.text(label: 'Save', size: EcButtonSize.small, onPressed: _valid == null ? null : _save),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EcSectionLabel('Project name'),
          EcTextField(
            controller: _controller,
            label: null,
            autofocus: true,
            maxLength: Project.maxTitleLength,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            helper: 'Used as the file name of every render.',
            counter: '${_controller.text.characters.length}/${Project.maxTitleLength}',
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
    );
  }
}
