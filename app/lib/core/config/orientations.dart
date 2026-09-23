import 'package:flutter/services.dart';

/// The app outside the editor.
const kPortraitOnly = [DeviceOrientation.portraitUp];

/// The editor: rotating to landscape opens the review monitor (3.4).
const kEditorOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];
