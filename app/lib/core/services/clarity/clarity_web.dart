import 'package:flutter/widgets.dart';

/// Web stand-ins for `clarity_flutter`: same names, no recording.

// ignore_for_file: constant_identifier_names
enum LogLevel { Verbose, Debug, Info, Warn, Error, None }

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
