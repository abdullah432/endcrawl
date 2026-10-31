import 'dart:js_interop';

import 'package:flutter/widgets.dart';

/// Web stand-ins for `clarity_flutter`: widgets pass through while [Clarity]
/// forwards user identification to the browser `window.clarity` tracker.

// ignore_for_file: constant_identifier_names
enum LogLevel { Verbose, Debug, Info, Warn, Error, None }

typedef SessionStartedCallback = void Function(String sessionId);

@JS('clarity')
external JSFunction? _clarityFn;

@JS('clarity')
external void _callClarity(JSString command, [JSString? arg]);

class Clarity {
  /// Links the active browser Clarity session to [customUserId] via
  /// `window.clarity("identify", customUserId)`.
  static bool setCustomUserId(String customUserId) {
    final trimmed = customUserId.trim();
    if (trimmed.isEmpty || trimmed.length > 255) return false;
    try {
      if (_clarityFn == null) return false;
      _callClarity('identify'.toJS, trimmed.toJS);
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool startNewSession(SessionStartedCallback callback) => false;
}

class ClarityConfig {
  final String projectId;
  final LogLevel logLevel;
  ClarityConfig({required this.projectId, this.logLevel = LogLevel.None});
}

class ClarityWidget extends StatelessWidget {
  final Widget app;
  final ClarityConfig clarityConfig;
  const ClarityWidget({super.key, required this.app, required this.clarityConfig});

  @override
  Widget build(BuildContext context) => app;
}

class ClarityMask extends StatelessWidget {
  final Widget child;
  const ClarityMask({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
