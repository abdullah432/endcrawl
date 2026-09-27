import 'package:lastreel/core/services/analytics.dart';

/// Records the collection switch instead of calling Google Analytics.
class FakeAnalytics implements AppAnalytics {
  final changes = <bool>[];

  bool? get enabled => changes.isEmpty ? null : changes.last;

  @override
  Future<void> setCollectionEnabled(bool enabled) async => changes.add(enabled);
}
