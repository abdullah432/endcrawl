import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/bootstrap.dart';
import 'package:lastreel/core/config/release_config.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/access/controllers/web_access.dart';
import 'package:lastreel/features/plan/controllers/release_policy.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('release flag reads the build define and defaults to enabled', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(iosFreeLaunchFlagProvider),
      const bool.fromEnvironment('IOS_FREE_LAUNCH', defaultValue: true),
    );
  });

  for (final enabled in [false, true]) {
    for (final platform in [
      TargetPlatform.iOS,
      TargetPlatform.android,
      TargetPlatform.macOS,
    ]) {
      for (final web in [false, true]) {
        test(
          'flag=$enabled platform=$platform web=$web scopes project access only',
          () async {
            debugDefaultTargetPlatformOverride = platform;
            const free = Entitlement.free(lapsed: true);
            final container = ProviderContainer(
              overrides: [
                iosFreeLaunchFlagProvider.overrideWithValue(enabled),
                runningOnWebProvider.overrideWithValue(web),
                entitlementProvider.overrideWith((ref) => Stream.value(free)),
              ],
            );
            addTearDown(container.dispose);
            container.listen(entitlementProvider, (_, _) {});
            await container.read(entitlementProvider.future);
            final active = enabled && platform == TargetPlatform.iOS && !web;
            expect(container.read(iosFreeLaunchProvider), active);
            expect(container.read(projectLimitProvider), active ? isNull : 2);
            expect(container.read(webPreviewProvider), web);
            expect(
              container.read(entitlementProvider).requireValue,
              same(free),
            );
            expect(free.isPro, isFalse);
            expect(free.showsAds, isTrue);
          },
        );
      }
    }
  }
}
