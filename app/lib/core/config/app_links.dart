import 'package:flutter/foundation.dart';

/// Addresses the app links out to. Last Reel's public pages live on
/// cookoo.dev, the COOKOO Technologies site.
abstract final class AppLinks {
  static const supportEmail = 'hello@cookoo.dev';

  /// Answers to common questions, with a way to reach support.
  static final helpCentre = Uri.parse('https://cookoo.dev/lastreel/help');

  /// The published policy, hosted on cookoo.dev — the same page the store
  /// listings link to, so there is only one version to keep current.
  static final privacyPolicy = Uri.parse('https://cookoo.dev/lastreel/privacy-policy');
  static String get storeName => defaultTargetPlatform == TargetPlatform.android ? 'Google Play' : 'App Store';
  static Uri get manageSubscriptions => Uri.parse(defaultTargetPlatform == TargetPlatform.android
      ? 'https://play.google.com/store/account/subscriptions?package=com.lastreel.app'
      : 'https://apps.apple.com/account/subscriptions');
}
