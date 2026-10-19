import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The SDK's own codec is required to exercise its platform callbacks.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:lastreel/core/config/ad_config.dart';
import 'package:lastreel/features/ads/data/ad_service.dart';
import 'package:lastreel/features/ads/data/admob_ad_service.dart';

class _Consent extends ConsentInformation {
  bool allowed = true;
  bool failUpdate = false;
  int updates = 0;

  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    OnConsentInfoUpdateSuccessListener successListener,
    OnConsentInfoUpdateFailureListener failureListener,
  ) {
    updates++;
    if (failUpdate) {
      failureListener(FormError(errorCode: 2, message: 'Offline'));
    }
    // Otherwise deliberately leave the refresh pending: cached consent
    // must permit ads without waiting for a network response.
  }

  @override
  Future<bool> canRequestAds() async => allowed;
  @override
  Future<ConsentStatus> getConsentStatus() async =>
      allowed ? ConsentStatus.obtained : ConsentStatus.unknown;
  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async =>
      PrivacyOptionsRequirementStatus.notRequired;
  @override
  Future<bool> isConsentFormAvailable() async => false;
  @override
  Future<void> reset() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  late _Consent consent;
  late ConsentInformation originalConsent;
  var initializationFails = false;
  var showFails = false;

  List<MethodCall> named(String name) =>
      calls.where((c) => c.method == name).toList();

  setUp(() {
    calls.clear();
    initializationFails = false;
    showFails = false;
    originalConsent = ConsentInformation.instance;
    consent = _Consent();
    ConsentInformation.instance = consent;
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(instanceManager.channel, (call) async {
          calls.add(call);
          if (showFails && call.method == 'showAdWithoutView') {
            throw PlatformException(code: 'show_failed');
          }
          if (call.method == 'MobileAds#initialize') {
            if (initializationFails) throw PlatformException(code: 'offline');
            return InitializationStatus({});
          }
          return null;
        });
  });

  tearDown(() {
    ConsentInformation.instance = originalConsent;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(instanceManager.channel, null);
  });

  Future<AdMobAdService> mount(
    WidgetTester tester, {
    AdPlacement placement = AdPlacement.library,
    AdUnits? units,
  }) async {
    final service = AdMobAdService(
      () => false,
      units:
          units ??
          AdUnits.forBuild(platform: TargetPlatform.iOS, releaseMode: false),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: service.nativeAd(
            placement,
            framed: (_) => const Text('Loaded creative'),
          ),
        ),
      ),
    );
    await tester.pump();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    });
    return service;
  }

  Future<void> event(
    WidgetTester tester,
    int id,
    String name, {
    LoadAdError? error,
    AdError? showError,
  }) async {
    final message = instanceManager.channel.codec.encodeMethodCall(
      MethodCall('onAdEvent', {
        'adId': id,
        'eventName': name,
        'loadAdError': ?error,
        'error': ?showError,
      }),
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(instanceManager.channel.name, message, (_) {});
    await tester.pump();
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'Settings requests its own native unit on $platform',
      (tester) async {
        final units = AdUnits.forBuild(platform: platform, releaseMode: true)!;
        await mount(tester, placement: AdPlacement.settings, units: units);
        final request = named('loadNativeAd').single.arguments as Map;
        expect(request['adUnitId'], units.settingsNative);
        expect(request['factoryId'], nativeCardFactoryId);
        expect(find.text('Loaded creative'), findsNothing);
        await event(tester, request['adId'] as int, 'onAdLoaded');
        expect(find.text('Loaded creative'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets(
    'cached consent loads while its network refresh is still pending',
    (tester) async {
      final service = await mount(tester);
      service.preloadAppOpen();
      await tester.pump();
      expect(consent.updates, 1);
      expect(named('MobileAds#initialize'), hasLength(1));
      expect(named('loadNativeAd'), hasLength(1));
      final id = (named('loadNativeAd').single.arguments as Map)['adId'] as int;
      await event(tester, id, 'onAdLoaded');
      expect(find.text('Loaded creative'), findsOneWidget);
    },
  );

  testWidgets(
    'failed native request retries after a delay, then displays the loaded ad',
    (tester) async {
      await mount(tester);
      final id = (named('loadNativeAd').single.arguments as Map)['adId'] as int;
      await event(
        tester,
        id,
        'onAdFailedToLoad',
        error: LoadAdError(2, 'network', 'Offline', null),
      );
      expect(find.text('Loaded creative'), findsNothing);
      await tester.pump(const Duration(seconds: 29));
      expect(named('loadNativeAd'), hasLength(1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(named('loadNativeAd'), hasLength(2));
      final nextId =
          (named('loadNativeAd').last.arguments as Map)['adId'] as int;
      await event(tester, nextId, 'onAdLoaded');
      expect(find.text('Loaded creative'), findsOneWidget);
    },
  );

  testWidgets(
    'consent failure stays closed, then a later attempt can recover',
    (tester) async {
      consent.allowed = false;
      consent.failUpdate = true;
      await mount(tester);
      expect(named('loadNativeAd'), isEmpty);
      expect(named('MobileAds#initialize'), isEmpty);
      consent.allowed = true;
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(named('loadNativeAd'), hasLength(1));
      expect(consent.updates, 2);
    },
  );

  testWidgets('an SDK startup exception does not poison every later request', (
    tester,
  ) async {
    initializationFails = true;
    await mount(tester);
    expect(named('loadNativeAd'), isEmpty);
    initializationFails = false;
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(named('MobileAds#initialize'), hasLength(2));
    expect(named('loadNativeAd'), hasLength(1));
  });

  testWidgets(
    'pending app-open retries stop requesting when the account becomes Pro',
    (tester) async {
      var enabled = true;
      final service = AdMobAdService(
        () => false,
        enabled: () => enabled,
        units: AdUnits.forBuild(
          platform: TargetPlatform.iOS,
          releaseMode: false,
        ),
      );
      addTearDown(service.dispose);
      consent.allowed = false;
      consent.failUpdate = true;
      service.preloadAppOpen();
      await tester.pump();
      enabled = false;
      await tester.pump(const Duration(seconds: 30));
      expect(consent.updates, 1);
      expect(named('loadAppOpenAd'), isEmpty);
    },
  );

  group('export interstitial', () {
    AdMobAdService service({
      bool Function()? enabled,
      DateTime Function()? now,
      TargetPlatform platform = TargetPlatform.android,
    }) {
      final result = AdMobAdService(
        () => false,
        units: AdUnits.forBuild(platform: platform, releaseMode: false),
        enabled: enabled,
        now: now,
      );
      addTearDown(result.dispose);
      return result;
    }

    Future<int> load(WidgetTester tester, AdMobAdService ads) async {
      ads.preloadExportInterstitial();
      await tester.pump();
      final id =
          (named('loadInterstitialAd').last.arguments as Map)['adId'] as int;
      await event(tester, id, 'onAdLoaded');
      return id;
    }

    testWidgets(
      'preloads once, shows cached inventory once, disposes and reloads after dismissal',
      (tester) async {
        final ads = service();
        ads.preloadExportInterstitial();
        ads.preloadExportInterstitial();
        await tester.pump();
        expect(named('loadInterstitialAd'), hasLength(1));
        expect(
          (named('loadInterstitialAd').single.arguments as Map)['adUnitId'],
          'ca-app-pub-3940256099942544/1033173712',
        );
        expect(named('showAdWithoutView'), isEmpty);
        final id =
            (named('loadInterstitialAd').single.arguments as Map)['adId']
                as int;
        await event(tester, id, 'onAdLoaded');
        await ads.showExportInterstitial();
        await ads.showExportInterstitial();
        await ads.showAppOpen();
        expect(await ads.showRewarded(), RewardOutcome.unavailable);
        expect(named('showAdWithoutView'), hasLength(1));
        expect(ads.showingFullScreen, isTrue);
        await event(tester, id, 'onAdDismissedFullScreenContent');
        expect(ads.showingFullScreen, isFalse);
        expect(named('disposeAd'), hasLength(1));
        expect(named('loadInterstitialAd'), hasLength(2));
      },
    );

    testWidgets('a request completing after Export does not open a late ad', (
      tester,
    ) async {
      final ads = service();
      ads.preloadExportInterstitial();
      await tester.pump();
      await ads.showExportInterstitial();
      final id =
          (named('loadInterstitialAd').single.arguments as Map)['adId'] as int;
      await event(tester, id, 'onAdLoaded');
      expect(named('showAdWithoutView'), isEmpty);
    });

    testWidgets('no fill retries with a delay and stops on disposal', (
      tester,
    ) async {
      final ads = service();
      ads.preloadExportInterstitial();
      await tester.pump();
      final id =
          (named('loadInterstitialAd').single.arguments as Map)['adId'] as int;
      await event(
        tester,
        id,
        'onAdFailedToLoad',
        error: LoadAdError(3, 'admob', 'No fill', null),
      );
      await ads.showExportInterstitial();
      expect(named('showAdWithoutView'), isEmpty);
      await tester.pump(const Duration(seconds: 30));
      expect(named('loadInterstitialAd'), hasLength(2));
      ads.dispose();
      await tester.pump(const Duration(minutes: 2));
      expect(named('loadInterstitialAd'), hasLength(2));
    });

    testWidgets(
      'consent and Pro gates prevent requests, including a late loaded ad',
      (tester) async {
        var enabled = false;
        final ads = service(enabled: () => enabled);
        ads.preloadExportInterstitial();
        await tester.pump();
        expect(named('loadInterstitialAd'), isEmpty);
        enabled = true;
        consent.allowed = false;
        consent.failUpdate = true;
        ads.preloadExportInterstitial();
        await tester.pump();
        expect(named('loadInterstitialAd'), isEmpty);
        consent.allowed = true;
        ads.preloadExportInterstitial();
        await tester.pump();
        final id =
            (named('loadInterstitialAd').single.arguments as Map)['adId']
                as int;
        enabled = false;
        await event(tester, id, 'onAdLoaded');
        await ads.showExportInterstitial();
        expect(named('showAdWithoutView'), isEmpty);
        expect(named('disposeAd'), hasLength(1));
      },
    );

    testWidgets('background completion never presents an ad', (tester) async {
      final ads = service();
      await load(tester, ads);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await ads.showExportInterstitial();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(named('showAdWithoutView'), isEmpty);
    });

    testWidgets('expired inventory is replaced without showing it', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 10, 19);
      final ads = service(now: () => now);
      await load(tester, ads);
      now = now.add(const Duration(hours: 1));
      await ads.showExportInterstitial();
      await tester.pump();
      expect(named('showAdWithoutView'), isEmpty);
      expect(named('disposeAd'), hasLength(1));
      expect(named('loadInterstitialAd'), hasLength(2));
    });

    testWidgets('SDK show failures release the full-screen lock and reload', (
      tester,
    ) async {
      final ads = service();
      await load(tester, ads);
      showFails = true;
      await ads.showExportInterstitial();
      await tester.pump();
      expect(ads.showingFullScreen, isFalse);
      expect(named('disposeAd'), hasLength(1));
      expect(named('loadInterstitialAd'), hasLength(2));
    });

    testWidgets('native presentation failure disposes and releases the lock', (
      tester,
    ) async {
      final ads = service();
      final id = await load(tester, ads);
      await ads.showExportInterstitial();
      await event(
        tester,
        id,
        'onFailedToShowFullScreenContent',
        showError: AdError(0, 'test', 'Presentation failed'),
      );
      expect(ads.showingFullScreen, isFalse);
      expect(named('disposeAd'), hasLength(1));
      expect(named('loadInterstitialAd'), hasLength(2));
    });

    for (final failsToPresent in [false, true]) {
      testWidgets(
        'iOS uses its own unit and releases the ad after ${failsToPresent ? 'presentation failure' : 'dismissal'}',
        (tester) async {
          final ads = service(platform: TargetPlatform.iOS);
          final id = await load(tester, ads);
          expect(
            (named('loadInterstitialAd').single.arguments as Map)['adUnitId'],
            'ca-app-pub-3940256099942544/4411468910',
          );
          await ads.showExportInterstitial();
          await ads.showExportInterstitial();
          expect(named('showAdWithoutView'), hasLength(1));
          expect(ads.showingFullScreen, isTrue);
          await event(
            tester,
            id,
            failsToPresent
                ? 'didFailToPresentFullScreenContentWithError'
                : 'adDidDismissFullScreenContent',
            showError: failsToPresent
                ? AdError(0, 'test', 'Presentation failed')
                : null,
          );
          expect(ads.showingFullScreen, isFalse);
          expect(named('disposeAd'), hasLength(1));
          expect(named('loadInterstitialAd'), hasLength(2));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  });
}
