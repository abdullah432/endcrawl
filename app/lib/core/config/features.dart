/// Product switches for things built but not offered yet. Each is a
/// compile-time constant, so a switched-off feature's UI is tree-shaken
/// while its code and tests stay ready.
abstract final class Features {
  /// Sign in with Apple. Off until the Apple provider and the Xcode
  /// capability are set up — see app/README.md, "Firebase setup".
  static const appleSignIn = false;

  /// The verify-email gate (0.5) for email & password sign-ups: sends the
  /// link at sign-up and holds unverified accounts on 0.5.
  ///
  /// On because of Google: with an unverified address, a later Google
  /// sign-in on the same Gmail makes Firebase drop the password from the
  /// account (Google is the trusted owner of the address), so email &
  /// password stops working. A verified address keeps both.
  static const emailVerification = true;
}
