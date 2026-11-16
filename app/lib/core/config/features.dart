import 'package:flutter/foundation.dart';

/// Product availability shared by sign-in and account settings.
abstract final class Features {
  /// Native Apple authentication on iPhone, iPad and Mac. Other platforms
  /// retain their existing Google and email sign-in options.
  static bool get appleSignIn =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// The verify-email gate (0.5) for email & password sign-ups: sends the
  /// link at sign-up and holds unverified accounts on 0.5.
  ///
  /// Disabled for now: email accounts enter the library directly, and
  /// registration does not send a verification email.
  static const emailVerification = false;
}
