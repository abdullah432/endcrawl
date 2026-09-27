import 'package:firebase_analytics/firebase_analytics.dart';

/// Usage analytics — Google Analytics for Firebase.
///
/// Collection is on by default (the SDK's own default); the "Usage
/// analytics" switch in Privacy & data turns it off for the account.
abstract interface class AppAnalytics {
  Future<void> setCollectionEnabled(bool enabled);
}

class FirebaseAppAnalytics implements AppAnalytics {
  const FirebaseAppAnalytics();

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
}
