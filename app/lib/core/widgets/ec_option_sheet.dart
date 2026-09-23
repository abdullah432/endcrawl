import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import 'ec_sheet.dart';

/// One choice in an [EcOptionSheet].
class EcOption<T> {
  final T value;
  final String label;
  final String? detail;
  const EcOption(this.value, this.label, {this.detail});
}

/// Pick one of a short list — the default frame rate and canvas on
/// Settings. Returns the chosen value, or null if dismissed.
class EcOptionSheet<T> extends StatelessWidget {
  final String title;
  final List<EcOption<T>> options;
  final T selected;

  const EcOptionSheet({super.key, required this.title, required this.options, required this.selected});

  static Future<T?> show<T>(BuildContext context, {required String title, required List<EcOption<T>> options, required T selected}) {
    return showEcSheet<T>(context, builder: (_) => EcOptionSheet<T>(title: title, options: options, selected: selected));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return EcSheet(
      title: title,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      child: Column(
        children: [
          for (final option in options)
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(option.label, style: t.row),
              subtitle: option.detail == null ? null : Text(option.detail!, style: t.mono),
              trailing: option.value == selected ? Icon(Icons.check_rounded, color: p.accentSolid) : null,
              selected: option.value == selected,
              onTap: () => Navigator.of(context).pop(option.value),
            ),
        ],
      ),
    );
  }
}
