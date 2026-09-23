import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../theme/tokens.dart';

/// One of a few side-by-side choices shown as cards — canvas formats (2.3),
/// monitor looks (5.2), backgrounds (5.3), billing periods (6.5). Selected
/// is white with the accent ring; the rest are glass.
class EcChoiceCard extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;
  final Widget child;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;
  final double radius;

  const EcChoiceCard({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(10),
    this.radius = EcRadius.card,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = BorderRadius.circular(radius);
    return Semantics(
      selected: selected,
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: AnimatedContainer(
        duration: EcMotion.fast,
        decoration: BoxDecoration(
          color: selected ? p.surface : p.glass,
          borderRadius: shape,
          border: Border.all(color: selected ? p.accentSolid : p.line, width: selected ? 1.5 : 1),
          boxShadow: selected ? [BoxShadow(color: p.accentWash, spreadRadius: 4)] : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      ),
    );
  }
}
