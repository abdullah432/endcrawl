import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/config/ad_config.dart';

void main() {
  test('sample native override is gated and leaves production fullscreen units intact', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const enabled = bool.fromEnvironment('AD_DIAGNOSTICS') &&
        bool.fromEnvironment('AD_NATIVE_TEST_ADS');
    expect(AdUnits.diagnosticNativeTestAds, enabled);
    expect(AdUnits.diagnosticNativeUnit,
        enabled ? 'ca-app-pub-3940256099942544/3986624511' : null);
    final production = AdUnits.forBuild(platform: TargetPlatform.iOS, releaseMode: true)!;
    expect(production.exportSuccessInterstitial, 'ca-app-pub-6644211975790806/7459691102');
  });
}
