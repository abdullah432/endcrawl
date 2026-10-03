import 'package:flutter/foundation.dart';

/// AdMob IDs per platform. Only release builds use the real units:
/// debug and profile builds — the simulator, `flutter run` on a device —
/// always get Google's test units, so development never serves or
/// clicks a real ad (which AdMob treats as invalid traffic).
///
/// The app ID lives in the platform config, not here: `GADApplicationIdentifier`
/// in ios/Runner/Info.plist and `com.google.android.gms.ads.APPLICATION_ID`
/// in android/app/src/main/AndroidManifest.xml.
class AdUnits {
  final String libraryNative;
  final String renderingNative;
  final String exportReadyNative;

  /// "Watch ad · render once" (6.1a) — a rewarded interstitial.
  final String proRenderRewarded;

  /// Shown when the app comes back from the background.
  final String appOpenResume;

  const AdUnits({
    required this.libraryNative,
    required this.renderingNative,
    required this.exportReadyNative,
    required this.proRenderRewarded,
    required this.appOpenResume,
  });

  /// The units for this build and platform, or null where there are none
  /// (a release build on a platform without real units yet shows no ads).
  static AdUnits? get current =>
      forBuild(platform: defaultTargetPlatform, releaseMode: kReleaseMode);

  @visibleForTesting
  static AdUnits? forBuild({
    required TargetPlatform platform,
    required bool releaseMode,
  }) => switch (platform) {
    TargetPlatform.android => releaseMode ? _androidRelease : _androidTest,
    TargetPlatform.iOS => releaseMode ? null : _iosTest,
    _ => null,
  };

  /// Verified Android app ca-app-pub-6644211975790806~5643195524.
  /// iOS release ads remain disabled until a separate iOS app is configured.
  static const _androidRelease = AdUnits(
    libraryNative: 'ca-app-pub-6644211975790806/6465497619',
    renderingNative: 'ca-app-pub-6644211975790806/7706337805',
    exportReadyNative: 'ca-app-pub-6644211975790806/4888602772',
    proRenderRewarded: 'ca-app-pub-6644211975790806/1799405002',
    appOpenResume: 'ca-app-pub-6644211975790806/6421176298',
  );

  // Google's published sample units: always test ads, safe to click.
  static const _iosTest = AdUnits(
    libraryNative: 'ca-app-pub-3940256099942544/3986624511',
    renderingNative: 'ca-app-pub-3940256099942544/3986624511',
    exportReadyNative: 'ca-app-pub-3940256099942544/3986624511',
    proRenderRewarded: 'ca-app-pub-3940256099942544/6978759866',
    appOpenResume: 'ca-app-pub-3940256099942544/5575463023',
  );

  static const _androidTest = AdUnits(
    libraryNative: 'ca-app-pub-3940256099942544/2247696110',
    renderingNative: 'ca-app-pub-3940256099942544/2247696110',
    exportReadyNative: 'ca-app-pub-3940256099942544/2247696110',
    proRenderRewarded: 'ca-app-pub-3940256099942544/5354046379',
    appOpenResume: 'ca-app-pub-3940256099942544/9257395921',
  );
}

/// The app-open ad shows on every return from the background; how often is
/// AdMob's frequency cap, set per unit in the console.
abstract final class AppOpenPolicy {
  /// Google discards app-open ads after four hours.
  static const maxAdAge = Duration(hours: 4);
}
