/// Product switches for things built but not offered yet. Each is a
/// compile-time constant, so a switched-off feature's UI is tree-shaken
/// while its code and tests stay ready.
abstract final class Features {
  /// Sign in with Apple. Off until the Apple provider and the Xcode
  /// capability are set up — see app/README.md, "Firebase setup".
  static const appleSignIn = false;
}
