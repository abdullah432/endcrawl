import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../theme/tokens.dart';

/// Shows [builder] as a centred modal over the app's scrim — what a bottom
/// sheet becomes on a tablet or a desktop browser, where a sheet would
/// stretch across a wide screen. Esc and a tap outside close it when
/// [dismissible].
Future<T?> showEcDialog<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: context.palette.scrim,
    builder: builder,
  );
}

/// The modal card: white, 28 px corners, a deep soft shadow, at most
/// [width] wide and never taller than the window — the body scrolls inside
/// it, and it lifts above the on-screen keyboard.
class EcDialog extends StatelessWidget {
  final Widget child;
  final double width;

  /// A fixed height for dialogs whose body manages its own scrolling (a
  /// two-column editor); null sizes to the content.
  final double? height;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final String? semanticLabel;

  const EcDialog({
    super.key,
    required this.child,
    this.width = 580,
    this.height,
    this.padding = const EdgeInsets.fromLTRB(36, 34, 36, 30),
    this.color,
    this.semanticLabel,
  });

  static const shadow = [
    BoxShadow(color: Color(0x99140C04), offset: Offset(0, 50), blurRadius: 100, spreadRadius: -40),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.viewInsets.bottom - media.padding.vertical - 48;
    final card = Container(
      width: width,
      height: height?.clamp(0, maxHeight).toDouble(),
      constraints: BoxConstraints(maxWidth: media.size.width - 32, maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(EcRadius.sheet),
        boxShadow: shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: height != null
            ? Padding(padding: padding, child: child)
            : SingleChildScrollView(padding: padding, child: child),
      ),
    );
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Center(child: card),
      ),
    );
  }
}
