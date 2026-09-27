import 'package:flutter/foundation.dart';

/// Addresses the app links out to.
///
/// PLACEHOLDERS — replace with the real support address, help centre and
/// App Store id before release. Kept in one file so that's a one-line job.
abstract final class AppLinks {
  static const supportEmail = 'support@lastreel.app';
  static final helpCentre = Uri.parse('https://lastreel.app/help');
  static String get storeName => defaultTargetPlatform == TargetPlatform.android ? 'Google Play' : 'App Store';
  static Uri get manageSubscriptions => Uri.parse(defaultTargetPlatform == TargetPlatform.android
      ? 'https://play.google.com/store/account/subscriptions?package=com.lastreel.app'
      : 'https://apps.apple.com/account/subscriptions');
}
