import 'package:firebase_analytics/firebase_analytics.dart';

/// Usage analytics — Google Analytics for Firebase.
///
/// Collection is on by default (the SDK's own default); the "Usage
/// analytics" switch in Privacy & data turns it off for the account.
abstract interface class AppAnalytics {
  Future<void> setCollectionEnabled(bool enabled);

  /// One product event — "trial_started" with `{plan: yearly, source: library}`.
  Future<void> logEvent(String name, [Map<String, Object> parameters = const {}]);
}

class FirebaseAppAnalytics implements AppAnalytics {
  const FirebaseAppAnalytics();

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);

  @override
  Future<void> logEvent(String name, [Map<String, Object> parameters = const {}]) async {
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters.isEmpty ? null : parameters);
    } catch (_) {
      // Analytics must never break the action it describes.
    }
  }
}
