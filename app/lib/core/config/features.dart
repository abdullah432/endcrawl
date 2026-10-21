import 'package:flutter/foundation.dart';

/// Product availability shared by sign-in and account settings.
abstract final class Features {
  /// Native Apple authentication on iPhone and iPad. Other platforms
  /// retain their existing Google and email sign-in options.
  static bool get appleSignIn =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// The verify-email gate (0.5) for email & password sign-ups: sends the
  /// link at sign-up and holds unverified accounts on 0.5.
  ///
  /// On because of Google: with an unverified address, a later Google
  /// sign-in on the same Gmail makes Firebase drop the password from the
  /// account (Google is the trusted owner of the address), so email &
  /// password stops working. A verified address keeps both.
  static const emailVerification = true;
}
