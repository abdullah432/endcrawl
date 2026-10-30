import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/config/ad_config.dart';

List<String> ids(AdUnits units) => [
  units.libraryNative,
  units.editorNative,
  units.timingLookNative,
  units.exportSettingsNative,
  units.renderingNative,
  units.exportReadyNative,
  units.proRenderRewarded,
  units.appOpenResume,
  ?units.exportSuccessInterstitial,
];

void main() {
  test('Android release uses the verified production placements', () {
    final units = AdUnits.forBuild(
      platform: TargetPlatform.android,
      releaseMode: true,
    )!;
    expect(ids(units), [
      'ca-app-pub-6644211975790806/6465497619',
      'ca-app-pub-6644211975790806/6890805343',
      'ca-app-pub-6644211975790806/2251596457',
      'ca-app-pub-6644211975790806/7487430088',
      'ca-app-pub-6644211975790806/7706337805',
      'ca-app-pub-6644211975790806/4888602772',
      'ca-app-pub-6644211975790806/1799405002',
      'ca-app-pub-6644211975790806/6421176298',
      'ca-app-pub-6644211975790806/4830936025',
    ]);
  });
  test('non-release mobile builds use only Google test units', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final units = AdUnits.forBuild(platform: platform, releaseMode: false)!;
      expect(
        ids(units),
        everyElement(startsWith('ca-app-pub-3940256099942544/')),
      );
    }
    expect(
      ids(AdUnits.current!),
      everyElement(startsWith('ca-app-pub-3940256099942544/')),
    );
  });
  test('iOS release uses the LastReel iOS production placements', () {
    final units = AdUnits.forBuild(
      platform: TargetPlatform.iOS,
      releaseMode: true,
    )!;
    expect(ids(units), [
      'ca-app-pub-6644211975790806/7231930165',
      'ca-app-pub-6644211975790806/1830050359',
      'ca-app-pub-6644211975790806/9235632198',
      'ca-app-pub-6644211975790806/8861677778',
      'ca-app-pub-6644211975790806/8683033622',
      'ca-app-pub-6644211975790806/2333072682',
      'ca-app-pub-6644211975790806/9584876749',
      'ca-app-pub-6644211975790806/2740441803',
      'ca-app-pub-6644211975790806/7459691102',
    ]);
  });

  test('each platform serves only its own production IDs, and others none', () {
    final android = ids(
      AdUnits.forBuild(platform: TargetPlatform.android, releaseMode: true)!,
    );
    final ios = ids(
      AdUnits.forBuild(platform: TargetPlatform.iOS, releaseMode: true)!,
    );
    expect(android.toSet().intersection(ios.toSet()), isEmpty);
    for (final platform in [
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.fuchsia,
    ]) {
      for (final releaseMode in [false, true]) {
        expect(
          AdUnits.forBuild(platform: platform, releaseMode: releaseMode),
          isNull,
        );
      }
    }
  });

  group('app IDs switch with the build', () {
    const testIos = 'ca-app-pub-3940256099942544~1458002511';
    const realIos = 'ca-app-pub-6644211975790806~3747523873';

    test('iOS reads the app ID from the build configuration', () {
      expect(
        File('ios/Runner/Info.plist').readAsStringSync(),
        contains('<string>\$(ADMOB_APP_ID)</string>'),
      );
      expect(
        File('ios/Flutter/Debug.xcconfig').readAsStringSync(),
        contains('ADMOB_APP_ID = $testIos'),
      );
      final release = File('ios/Flutter/Release.xcconfig').readAsStringSync();
      expect(release, contains('ADMOB_APP_ID = $realIos'));
      // Profile shares Release.xcconfig but serves test units.
      expect(release, contains('ADMOB_APP_ID[config=Profile] = $testIos'));
    });

    test('Android uses the test app ID except in release', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(
        gradle,
        contains(
          'manifestPlaceholders["admobAppId"] = "ca-app-pub-3940256099942544~3347511713"',
        ),
      );
      expect(
        gradle,
        contains(
          'manifestPlaceholders["admobAppId"] = "ca-app-pub-6644211975790806~5643195524"',
        ),
      );
    });
  });
}
