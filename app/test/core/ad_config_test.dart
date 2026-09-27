import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/config/ad_config.dart';

List<String> ids(AdUnits units) => [
  units.libraryNative,
  units.renderingNative,
  units.exportReadyNative,
  units.proRenderRewarded,
  units.appOpenResume,
];

void main() {
  test('Android release uses the verified production placements', () {
    final units = AdUnits.forBuild(
      platform: TargetPlatform.android,
      releaseMode: true,
    )!;
    expect(ids(units), [
      'ca-app-pub-6644211975790806/6465497619',
      'ca-app-pub-6644211975790806/7706337805',
      'ca-app-pub-6644211975790806/4888602772',
      'ca-app-pub-6644211975790806/1799405002',
      'ca-app-pub-6644211975790806/6421176298',
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
  test(
    'Android production IDs cannot leak to iOS or unsupported platforms',
    () {
      expect(
        AdUnits.forBuild(platform: TargetPlatform.iOS, releaseMode: true),
        isNull,
      );
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
    },
  );
}
