import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../theme/tokens.dart';

/// The design's button variants (Foundations → Parts, plus the two brand
/// buttons on the sign-in screens).
enum EcButtonVariant {
  /// Azure → violet gradient, white label. One per screen.
  primary,

  /// White fill, `line2` border, ink label.
  secondary,

  /// Solid warn fill, white label — only for the confirming step of a
  /// destructive action.
  destructive,

  /// Solid black — "Continue with Apple", per Apple's guidelines.
  black,

  /// Solid ink, small — the "Upgrade" pill on the library slot card.
  ink,

  /// No fill, accent label — "Forgot password?", "Use a different email".
  text,

  /// No fill, ink label — "Sign up with email" under the brand buttons.
  plain,
}

enum EcButtonSize {
  /// 54 px — the main action at the bottom of a screen.
  large,

  /// 44 px — inline actions inside cards.
  medium,

  /// 36 px — compact pills.
  small,
}

/// Every pill button in the app.
///
/// One widget with variants instead of five, so height, radius, press
/// feedback and the busy state are identical everywhere, and a busy button
/// keeps its size so nothing shifts under the user's thumb.
class EcButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final EcButtonVariant variant;
  final EcButtonSize size;
  final bool busy;
  final Widget? leading;

  /// Stretch to the available width. Defaults to true for large buttons.
  final bool? expand;

  const EcButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = EcButtonVariant.primary,
    this.size = EcButtonSize.large,
    this.busy = false,
    this.leading,
    this.expand,
  });

  const EcButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = EcButtonSize.large,
    this.busy = false,
    this.leading,
    this.expand,
  }) : variant = EcButtonVariant.secondary;

  const EcButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = EcButtonSize.medium,
    this.leading,
    this.expand,
  })  : variant = EcButtonVariant.text,
        busy = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final enabled = onPressed != null && !busy;

    final height = switch (size) {
      EcButtonSize.large => 54.0,
      EcButtonSize.medium => 44.0,
      EcButtonSize.small => 36.0,
    };
    final (Color fg, Color? fill, Gradient? gradient, Border? border, List<BoxShadow>? shadow) = switch (variant) {
      EcButtonVariant.primary => (p.onInk, null, p.primary, null, p.primaryShadow),
      EcButtonVariant.secondary => (p.ink, p.surface, null, Border.all(color: p.line2), null),
      EcButtonVariant.destructive => (p.onInk, p.warnFill, null, null, null),
      EcButtonVariant.black => (p.onInk, const Color(0xFF000000), null, null, null),
      EcButtonVariant.ink => (p.onInk, p.inkSurface, null, null, null),
      EcButtonVariant.text => (p.accent, null, null, null, null),
      EcButtonVariant.plain => (p.ink, null, null, null, null),
    };
    final labelStyle = (size == EcButtonSize.large ? t.button : t.buttonSmall).copyWith(
      color: fg,
      fontWeight: variant == EcButtonVariant.primary || variant == EcButtonVariant.destructive
          ? FontWeight.w700
          : FontWeight.w600,
      fontSize: switch (size) {
        EcButtonSize.large => 15,
        EcButtonSize.medium => 14,
        EcButtonSize.small => 12.5,
      },
    );

    final content = busy
        ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 10)],
                Text(label, style: labelStyle, maxLines: 1),
              ],
            ),
          );

    final stretch = expand ?? size == EcButtonSize.large;
    final horizontal = size == EcButtonSize.small ? 14.0 : 18.0;

    return Opacity(
      opacity: enabled || busy ? 1 : 0.45,
      child: Container(
        height: height,
        width: stretch ? double.infinity : null,
        decoration: BoxDecoration(
          color: fill,
          gradient: gradient,
          border: border,
          borderRadius: BorderRadius.circular(EcRadius.pill),
          boxShadow: enabled ? shadow : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              child: Center(widthFactor: 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// An inline accent link inside running text: "New to EndCrawl? **Create
/// account**". Kept separate from [EcButton.text] because it sits in a
/// sentence rather than taking a button's height.
class EcInlineLink extends StatelessWidget {
  final String lead;
  final String action;
  final VoidCallback? onTap;

  const EcInlineLink({super.key, required this.lead, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$lead ', style: t.body.copyWith(color: context.palette.muted)),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Text(action, style: t.body.copyWith(color: context.palette.accent, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
