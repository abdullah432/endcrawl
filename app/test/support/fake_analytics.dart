import 'package:lastreel/core/services/analytics.dart';

/// Records the collection switch and events instead of calling Google
/// Analytics.
class FakeAnalytics implements AppAnalytics {
  final changes = <bool>[];
  final events = <(String, Map<String, Object>)>[];

  /// The names of the events logged, in order.
  List<String> get names => [for (final (name, _) in events) name];

  @override
  Future<void> logEvent(String name, [Map<String, Object> parameters = const {}]) async =>
      events.add((name, parameters));

  bool? get enabled => changes.isEmpty ? null : changes.last;

  @override
  Future<void> setCollectionEnabled(bool enabled) async => changes.add(enabled);
}
