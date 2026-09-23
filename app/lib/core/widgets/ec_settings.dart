import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../theme/tokens.dart';
import 'ec_sheet.dart';

/// A labelled group of rows on one glass card, divided by hairlines —
/// Settings (7.1), Privacy & data (7.4), Subscription (7.3).
class EcGroup extends StatelessWidget {
  final String? label;
  final List<Widget> children;

  const EcGroup({super.key, this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) EcSectionLabel(label!),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.glassStrong,
            borderRadius: BorderRadius.circular(EcRadius.card),
            border: Border.all(color: p.glassEdge),
            boxShadow: p.rowShadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.line, indent: 16, endIndent: 0),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A row in an [EcGroup]: title, optional subtitle, and either a value with
/// a chevron, a switch, or nothing.
class EcGroupRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool chevron;

  const EcGroupRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.chevron = true,
  });

  /// A row whose trailing control is a switch; tapping the row toggles it.
  factory EcGroupRow.toggle({
    Key? key,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return EcGroupRow(
      key: key,
      title: title,
      subtitle: subtitle,
      chevron: false,
      onTap: onChanged == null ? null : () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: t.row.copyWith(color: destructive ? p.warn : p.ink)),
                      if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: t.caption)],
                    ],
                  ),
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(value!, style: t.body.copyWith(color: p.muted)),
              ],
              ?trailing,
              if (trailing == null && chevron && onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 20, color: p.faint),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
