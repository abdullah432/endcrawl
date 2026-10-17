import 'package:flutter/widgets.dart';

/// The three layouts the design draws: the phone (compact), a landscape
/// tablet (medium, the T-screens) and a desktop browser (expanded, the
/// D-screens).
///
/// Chosen by the window's width alone, so a tablet turned to portrait or a
/// narrowed browser simply gets the layout that fits. Every layout reads
/// the same providers, so switching between them keeps the open project,
/// the selection, undo history and playback.
enum LayoutClass {
  compact,
  medium,
  expanded;

  bool get isWide => this != compact;
}

abstract final class Breakpoints {
  /// Below this, the phone layout.
  static const medium = 720.0;

  /// From here, the desktop layout (the design's 1440 px browser; a
  /// 1194 px landscape tablet stays on medium).
  static const expanded = 1280.0;

  /// Shorter than this, a window is a phone on its side (the landscape
  /// review monitor), however wide it is.
  static const minWideHeight = 500.0;

  static LayoutClass forSize(Size size) => size.width < medium || size.height < minWideHeight
      ? LayoutClass.compact
      : size.width >= expanded
      ? LayoutClass.expanded
      : LayoutClass.medium;
}

extension LayoutContext on BuildContext {
  LayoutClass get layoutClass => Breakpoints.forSize(MediaQuery.sizeOf(this));
}
