import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';

/// The app outside the editor, on a phone.
const kPortraitOnly = [DeviceOrientation.portraitUp];

/// The editor on a phone: rotating to landscape opens the review monitor
/// (3.4).
const kEditorOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Every orientation — a tablet, whose layouts (T-screens) are drawn for
/// landscape and reflow for portrait.
const kAllOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// A tablet by its shorter side, the usual 600 dp line — fixed for the
/// device, unlike the window's width.
bool get isTabletDevice {
  final view = PlatformDispatcher.instance.implicitView;
  if (view == null) return false;
  return (view.physicalSize / view.devicePixelRatio).shortestSide >= 600;
}

/// Outside the editor: portrait on a phone, free on a tablet.
List<DeviceOrientation> get appOrientations => isTabletDevice ? kAllOrientations : kPortraitOnly;

/// In the editor: a phone may turn for the review monitor; a tablet turns
/// freely and keeps its editor layout.
List<DeviceOrientation> get editorOrientations => isTabletDevice ? kAllOrientations : kEditorOrientations;
