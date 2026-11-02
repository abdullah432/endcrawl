import 'package:flutter/foundation.dart';

/// Enabled explicitly for a diagnostic release; retained only in memory.
const adDiagnosticsEnabled = bool.fromEnvironment('AD_DIAGNOSTICS');
final adDiagnosticEvents = ValueNotifier<List<String>>(const []);

void recordAdDiagnostic(String message) {
  if (!adDiagnosticsEnabled) return;
  debugPrint("Ad diagnostics: $message");
  final events = [
    ...adDiagnosticEvents.value,
    '${DateTime.now().toIso8601String()} $message',
  ];
  adDiagnosticEvents.value = List.unmodifiable(
    events.skip(events.length > 100 ? events.length - 100 : 0),
  );
}
