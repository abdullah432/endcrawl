import 'package:flutter/material.dart';

import '../theme/ec_type.dart';
import '../theme/theme_context.dart';
import '../theme/tokens.dart';

/// A glass card: translucent white over the ground, white hairline edge,
/// soft warm shadow. The container every list item and panel is built on.
class EcGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  /// Opaque white with an accent ring — a highlighted card (the fresh copy
  /// on 1.7, the plan card on 7.1).
  final bool highlighted;

  /// `glassStrong` fill, for grouped settings and dense panels.
  final bool strong;

  const EcGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(7),
    this.radius = EcRadius.card,
    this.onTap,
    this.highlighted = false,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        color: highlighted ? p.surface : (strong ? p.glassStrong : p.glass),
        borderRadius: shape,
        border: Border.all(color: highlighted ? p.accentSolid : p.glassEdge, width: highlighted ? 1.5 : 1),
        boxShadow: [
          if (highlighted) BoxShadow(color: p.accentWash, spreadRadius: 5),
          ...p.glassShadow,
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// A glass list row — code tile, title, subtitle, trailing — radius 16.
class EcGlassRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry padding;

  const EcGlassRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final shape = BorderRadius.circular(EcRadius.row);
    return Container(
      decoration: BoxDecoration(
        color: selected ? p.accentWash : p.glass,
        borderRadius: shape,
        border: Border.all(color: selected ? p.accentLine : p.glassEdge),
        boxShadow: p.rowShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: t.titleS.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (subtitleWidget != null) ...[const SizedBox(height: 2), subtitleWidget!]
                      else if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: t.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 36 px three-letter block code tile — "CST", "DPT", "TTL".
class EcCodeTile extends StatelessWidget {
  final String code;
  final bool selected;
  final bool warn;
  final double size;

  const EcCodeTile(this.code, {super.key, this.selected = false, this.warn = false, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (fill, fg) = selected
        ? (null, p.onInk)
        : warn
            ? (p.warnWash, p.warn)
            : (p.accentWash, p.accent);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        gradient: selected ? p.primary : null,
        borderRadius: BorderRadius.circular(EcRadius.tile),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 18, color: fg)
          : Text(code, style: context.type.code.copyWith(color: fg)),
    );
  }
}

enum EcTone { ok, warn, accent, neutral }

/// A small mono status pill — "RENDERED", "RENDER FAILED", "TOO FAST".
class EcStatusPill extends StatelessWidget {
  final String label;
  final EcTone tone;

  const EcStatusPill(this.label, {super.key, this.tone = EcTone.neutral});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (fill, fg) = switch (tone) {
      EcTone.ok => (p.okWash, p.ok),
      EcTone.warn => (p.warnWash, p.warn),
      EcTone.accent => (p.accentWash, p.accent),
      EcTone.neutral => (p.tint, p.ink2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(EcRadius.pill)),
      child: Text(caps(label), style: context.type.pill.copyWith(color: fg)),
    );
  }
}

/// A tinted notice panel with a round glyph, a title and a body — the
/// "Check your inbox" confirmation, the readability warning, the unparsed
/// rows notice. Optional [actions] sit underneath.
class EcNotice extends StatelessWidget {
  final EcTone tone;
  final String title;
  final String? body;
  final Widget? bodyWidget;
  final List<Widget> actions;
  final IconData? icon;

  const EcNotice({
    super.key,
    required this.tone,
    required this.title,
    this.body,
    this.bodyWidget,
    this.actions = const [],
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final (wash, solid, border) = switch (tone) {
      EcTone.ok => (p.okWash, p.ok, null),
      EcTone.warn => (p.warnWash, p.warnFill, p.warnLine),
      EcTone.accent => (p.accentWash, p.accentSolid, p.accentLine),
      EcTone.neutral => (p.tint, p.ink2, null),
    };
    final glyph = icon ?? (tone == EcTone.ok ? Icons.check_rounded : Icons.priority_high_rounded);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(EcRadius.card),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: solid, shape: BoxShape.circle),
                child: Icon(glyph, size: 14, color: p.onInk),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleS.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
                    if (bodyWidget != null) ...[const SizedBox(height: 3), bodyWidget!]
                    else if (body != null) ...[const SizedBox(height: 3), Text(body!, style: t.bodyS)],
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: actions),
          ],
        ],
      ),
    );
  }
}

/// A round avatar with the user's initials — gradient on Settings, white on
/// the Library header.
class EcAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final bool gradient;
  final VoidCallback? onTap;

  const EcAvatar({super.key, required this.initials, this.size = 44, this.gradient = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: onTap != null,
      label: 'Account',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient ? p.primary : null,
            color: gradient ? null : p.surface,
            border: gradient ? null : Border.all(color: p.line),
            boxShadow: gradient ? p.primaryShadow : null,
          ),
          child: Text(
            initials,
            style: context.type.titleS.copyWith(
              fontSize: size * 0.3,
              fontWeight: FontWeight.w700,
              color: gradient ? p.onInk : p.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// A hairline with a word in the middle — "or".
class EcOrDivider extends StatelessWidget {
  final String label;
  const EcOrDivider({super.key, this.label = 'or'});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Container(height: 1, color: context.palette.line2));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: context.type.label.copyWith(fontWeight: FontWeight.w400, color: context.palette.muted)),
        ),
        line,
      ],
    );
  }
}

/// A 36 px round glyph badge — the icon column in action sheets.
class EcIconBadge extends StatelessWidget {
  final IconData icon;
  final bool destructive;
  final double size;

  const EcIconBadge(this.icon, {super.key, this.destructive = false, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: destructive ? p.warnWash : p.accentWash, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.44, color: destructive ? p.warn : p.accent),
    );
  }
}

/// A mono, upper-cased, tracked eyebrow — "REEL · 2 OF 3 · FREE".
class EcEyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const EcEyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) =>
      Text(caps(text), style: context.type.eyebrow.copyWith(color: color));
}
