import 'package:flutter/foundation.dart';

abstract final class BillingConfig {
  static const entitlementId = 'pro';
  // Public client SDK keys, never service-account or secret REST API keys.
  static const androidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: 'goog_XFpnptoQmhKhMSCFkMdSYBELVtB',
  );
  static const iosKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');

  /// The Firebase Auth custom claim RevenueCat's Firebase extension sets
  /// with the account's active entitlement ids. The web reads Pro from it:
  /// the server writes the claim, so a browser can't grant itself Pro.
  static const entitlementsClaim = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENTS_CLAIM',
    defaultValue: 'revenueCatEntitlements',
  );

  static String get apiKey => kIsWeb
      ? ''
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => androidKey,
          TargetPlatform.iOS => iosKey,
          _ => '',
        };
}
