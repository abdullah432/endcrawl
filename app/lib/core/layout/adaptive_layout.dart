import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum EcLayout { compact, spacious, tablet, desktop }

EcLayout layoutForWidth(double width) => switch (width) {
  < 600 => EcLayout.compact,
  < 768 => EcLayout.spacious,
  < 1280 => EcLayout.tablet,
  _ => EcLayout.desktop,
};

bool isNativePhone(BuildContext context) {
  if (kIsWeb) return false;
  final display = View.of(context).display;
  return display.size.shortestSide / display.devicePixelRatio < 600;
}

/// Bounds readable content without constraining the surrounding screen ground.
class EcContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const EcContentWidth({super.key, required this.child, this.maxWidth = 640});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
