import 'package:flutter/material.dart';

import '../layout/layout_class.dart';
import '../theme/ec_type.dart';
import '../theme/theme_context.dart';
import '../theme/tokens.dart';
import 'ec_sheet.dart';

/// Draws the [EcGroup]s below it as the tablet's Settings cards (T7.1,
/// P7.1): white, a hairline border, the label inside in mono, rows on
/// full-width rules, and values in mono with a "›".
class EcTabletSettings extends InheritedWidget {
  const EcTabletSettings({super.key, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<EcTabletSettings>() != null;

  @override
  bool updateShouldNotify(EcTabletSettings oldWidget) => false;
}

/// A labelled group of rows on one glass card, divided by hairlines —
/// Settings (7.1), Privacy & data (7.4), Subscription (7.3).
class EcGroup extends StatelessWidget {
  final String? label;

  /// A quiet note on the label's right — "By COOKOO".
  final String? trailing;
  final List<Widget> children;

  const EcGroup({super.key, this.label, this.trailing, required this.children});

  Widget? _note(BuildContext context) => trailing == null
      ? null
      : Text(caps(trailing!), style: context.type.mono.copyWith(fontSize: 9, letterSpacing: 1, color: context.palette.faint));

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (EcTabletSettings.of(context)) {
      return Container(
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.fromLTRB(0, label == null ? 6 : 18, 0, 6),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          caps(label!),
                          style: context.type.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.4),
                        ),
                      ),
                      ?_note(context),
                    ],
                  ),
                ),
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, color: p.line, indent: 22, endIndent: 22),
                children[i],
              ],
            ],
          ),
        ),
      );
    }
    // Tablet and desktop (T7.1, D15) draw each group as a white card with
    // its label inside; the phone keeps the label above a glass card.
    if (context.layoutClass.isWide) {
      return Container(
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.fromLTRB(8, label == null ? 6 : 20, 8, 6),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(EcRadius.group),
          boxShadow: p.glassShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Padding(padding: const EdgeInsets.only(left: 10, right: 6), child: EcSectionLabel(label!, trailing: _note(context))),
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 1, color: p.line, indent: 16, endIndent: 16),
                children[i],
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) EcSectionLabel(label!, trailing: _note(context)),
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
    if (EcTabletSettings.of(context)) {
      final arrow = trailing == null && chevron && onTap != null;
      return InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle == null ? 48 : 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: t.row.copyWith(
                            fontWeight: destructive ? FontWeight.w600 : FontWeight.w400,
                            color: destructive ? p.warn : p.ink,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 1),
                          Text(subtitle!, style: t.caption.copyWith(fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                if (value != null || arrow)
                  Text(
                    [?value, if (arrow) '›'].join(' '),
                    style: t.mono.copyWith(fontSize: 13.5, color: value == null ? p.faint : p.ink2),
                  ),
                ?trailing,
              ],
            ),
          ),
        ),
      );
    }
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
