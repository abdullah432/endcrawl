import 'package:flutter/foundation.dart';

abstract final class BillingConfig {
  static const entitlementId = 'pro';
  // Public client SDK keys, never service-account or secret REST API keys.
  static const androidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: 'goog_XFpnptoQmhKhMSCFkMdSYBELVtB',
  );
  static const iosKey = String.fromEnvironment('REVENUECAT_IOS_API_KEY');

  static String get apiKey => kIsWeb
      ? ''
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => androidKey,
          TargetPlatform.iOS => iosKey,
          _ => '',
        };
}
