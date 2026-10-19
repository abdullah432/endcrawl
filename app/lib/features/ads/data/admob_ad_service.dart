import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/ad_config.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/ec_palette.dart';
import 'ad_service.dart';

/// [AdService] on Google AdMob.
///
/// Nothing loads until the first ad is actually wanted, and that only ever
/// happens on the free plan — Pro users never start the SDK. Before the
/// first request it runs Google's consent flow (UMP), which shows the
/// consent form where the law asks for one (EEA, UK), and it asks for
/// non-personalised ads unless the user switched personalised ads on in
/// Privacy & data (7.4).
class AdMobAdService implements AdService {
  final AdUnits? _units;
  final bool Function() _personalised;
  final bool Function() _enabled;

  Future<bool>? _ready;
  AppOpenAd? _appOpen;
  DateTime? _appOpenLoadedAt;
  bool _appOpenLoading = false;
  bool _fullScreen = false;
  bool _disposed = false;
  Timer? _appOpenRetry;
  int _appOpenAttempts = 0;
  InterstitialAd? _exportInterstitial;
  DateTime? _exportInterstitialLoadedAt;
  bool _exportInterstitialLoading = false;
  bool _exportInterstitialShowing = false;
  Timer? _exportInterstitialRetry;
  int _exportInterstitialAttempts = 0;
  final DateTime Function() _now;

  /// [_personalised] reads the user's personalised-ads choice at request time.
  AdMobAdService(
    this._personalised, {
    AdUnits? units,
    bool Function()? enabled,
    DateTime Function()? now,
  }) : _units = units ?? AdUnits.current,
       _enabled = enabled ?? (() => true),
       _now = now ?? DateTime.now;

  /// Consent, then the SDK. False when ads can't be requested — no units
  /// for this platform, or consent not given.
  Future<bool> _ensureReady() {
    if (_disposed || !_enabled()) return Future.value(false);
    final pending = _ready;
    if (pending != null) return pending;
    final attempt = _start();
    _ready = attempt;
    attempt.then((ready) {
      if (!ready && identical(_ready, attempt)) _ready = null;
    });
    return attempt;
  }

  Future<bool> _start() async {
    if (_units == null || _disposed) return false;
    try {
      final consent = Completer<void>();
      void complete() {
        if (!consent.isCompleted) consent.complete();
      }

      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired((error) {
              if (error != null) {
                debugPrint(
                  'AdMob: consent form failed — ${error.errorCode}: ${error.message}',
                );
              }
            });
          } catch (error) {
            debugPrint('AdMob: consent form failed — $error');
          } finally {
            complete();
          }
        },
        (error) {
          debugPrint(
            'AdMob: consent update failed — ${error.errorCode}: ${error.message}',
          );
          complete();
        },
      );
      // UMP can already permit requests from a previous session. Do not
      // block those ads behind a slow consent network refresh.
      if (!await ConsentInformation.instance.canRequestAds()) {
        await consent.future;
      }
      if (_disposed ||
          !_enabled() ||
          !await ConsentInformation.instance.canRequestAds()) {
        debugPrint('AdMob: consent does not allow ad requests yet');
        return false;
      }
      await MobileAds.instance.initialize();
      debugPrint(
        'AdMob: SDK ready (${_units.libraryNative.contains('3940256099942544') ? 'test' : 'production'} units)',
      );
      return !_disposed && _enabled();
    } catch (error) {
      debugPrint('AdMob: initialization failed — $error');
      return false;
    }
  }

  AdRequest get _request => AdRequest(nonPersonalizedAds: !_personalised());

  String _nativeUnit(AdPlacement placement) => switch (placement) {
    AdPlacement.library => _units!.libraryNative,
    AdPlacement.settings => _units!.settingsNative,
    AdPlacement.rendering => _units!.renderingNative,
    AdPlacement.exportComplete => _units!.exportReadyNative,
  };

  @override
  Widget nativeAd(
    AdPlacement placement, {
    required Widget Function(Widget creative) framed,
    AdSlotStyle style = const AdSlotStyle(),
  }) {
    if (_units == null) return const SizedBox.shrink();
    return _NativeAdView(
      key: ValueKey((placement, style.layout, style.portrait)),
      style: style,
      load: (colours, listener) async {
        if (!await _ensureReady()) return null;
        final ad = NativeAd(
          adUnitId: _nativeUnit(placement),
          factoryId: nativeCardFactoryId,
          customOptions: colours,
          request: _request,
          listener: listener,
          nativeAdOptions: NativeAdOptions(
            adChoicesPlacement: AdChoicesPlacement.topRightCorner,
          ),
        );
        try {
          await ad.load();
          return ad;
        } catch (_) {
          ad.dispose();
          rethrow;
        }
      },
      framed: framed,
    );
  }

  @override
  Future<RewardOutcome> showRewarded() async {
    if (_fullScreen) return RewardOutcome.unavailable;
    if (!await _ensureReady()) return RewardOutcome.unavailable;
    final loaded = Completer<RewardedInterstitialAd?>();
    await RewardedInterstitialAd.load(
      adUnitId: _units!.proRenderRewarded,
      request: _request,
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: loaded.complete,
        onAdFailedToLoad: (error) {
          _logFailure('rewarded', error);
          loaded.complete(null);
        },
      ),
    );
    final ad = await loaded.future;
    if (ad == null) return RewardOutcome.unavailable;
    if (_disposed || !_enabled() || _fullScreen) {
      ad.dispose();
      return RewardOutcome.unavailable;
    }

    var earned = false;
    final ended = Completer<RewardOutcome>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _fullScreen = false;
        ended.complete(
          earned ? RewardOutcome.earned : RewardOutcome.closedEarly,
        );
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _fullScreen = false;
        ended.complete(RewardOutcome.unavailable);
      },
    );
    _fullScreen = true;
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return ended.future;
  }

  @override
  bool get showingFullScreen => _fullScreen;

  @override
  Future<void> showAppOpen() async {
    if (_disposed || _fullScreen || !await _ensureReady()) return;
    if (_disposed || !_enabled() || _fullScreen) return;
    final ad = _appOpen;
    final fresh =
        _appOpenLoadedAt != null &&
        DateTime.now().difference(_appOpenLoadedAt!) < AppOpenPolicy.maxAdAge;
    if (ad == null || !fresh) {
      ad?.dispose();
      _appOpen = null;
      _appOpenAttempts = 0;
      _loadAppOpen();
      return;
    }
    _appOpen = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _fullScreen = false;
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _fullScreen = false;
        _loadAppOpen();
      },
    );
    _fullScreen = true;
    await ad.show();
  }

  @override
  void preloadAppOpen() {
    if (_disposed || !_enabled() || _units == null || _appOpen != null) return;
    _ensureReady().then((ready) {
      if (_disposed) return;
      if (ready && _appOpen == null) {
        _loadAppOpen();
      } else if (!ready) {
        _appOpenAttempts++;
        _retryAppOpen();
      }
    });
  }

  /// Loads the next app-open ad ahead of time, so a resume shows it at once.
  void _loadAppOpen() {
    if (_disposed || !_enabled() || _appOpenLoading) return;
    _appOpenRetry?.cancel();
    _appOpenLoading = true;
    _appOpenAttempts++;
    AppOpenAd.load(
      adUnitId: _units!.appOpenResume,
      request: _request,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenLoading = false;
          if (_disposed || !_enabled()) {
            ad.dispose();
            return;
          }
          _appOpen = ad;
          _appOpenLoadedAt = DateTime.now();
          _appOpenAttempts = 0;
          debugPrint('AdMob: app open ad loaded');
        },
        onAdFailedToLoad: (error) {
          _appOpenLoading = false;
          _logFailure('app open', error);
          _retryAppOpen();
        },
      ),
    );
  }

  void _retryAppOpen() {
    if (_disposed || _appOpenAttempts >= AdRetryPolicy.maxAttempts) return;
    _appOpenRetry?.cancel();
    _appOpenRetry = Timer(
      AdRetryPolicy.delay(_appOpenAttempts),
      preloadAppOpen,
    );
  }

  @override
  void preloadExportInterstitial() {
    if (_disposed ||
        !_enabled() ||
        _units?.exportSuccessInterstitial == null ||
        _exportInterstitialLoading ||
        _exportInterstitial != null) {
      return;
    }
    _exportInterstitialRetry?.cancel();
    _exportInterstitialLoading = true;
    unawaited(_loadExportInterstitial());
  }

  void _exportLoadFinished() => _exportInterstitialLoading = false;

  Future<void> _loadExportInterstitial() async {
    _exportInterstitialAttempts++;
    try {
      if (!await _ensureReady()) {
        _exportLoadFinished();
        _retryExportInterstitial();
        return;
      }
      if (_disposed || !_enabled()) {
        _exportLoadFinished();
        return;
      }
      await InterstitialAd.load(
        adUnitId: _units!.exportSuccessInterstitial!,
        request: _request,
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (_disposed || !_enabled()) {
              ad.dispose();
              _exportLoadFinished();
              return;
            }
            _exportInterstitial = ad;
            _exportInterstitialLoadedAt = _now();
            _exportInterstitialAttempts = 0;
            debugPrint('AdMob: export interstitial loaded');
            _exportLoadFinished();
          },
          onAdFailedToLoad: (error) {
            _exportLoadFinished();
            _logFailure('export interstitial', error);
            _retryExportInterstitial();
          },
        ),
      );
    } catch (error) {
      _exportLoadFinished();
      debugPrint('AdMob: export interstitial load failed — $error');
      _retryExportInterstitial();
    }
  }

  void _retryExportInterstitial() {
    if (_disposed ||
        !_enabled() ||
        _exportInterstitialAttempts >= AdRetryPolicy.maxAttempts) {
      return;
    }
    _exportInterstitialRetry?.cancel();
    _exportInterstitialRetry = Timer(
      AdRetryPolicy.delay(_exportInterstitialAttempts),
      preloadExportInterstitial,
    );
  }

  @override
  Future<void> showExportInterstitial() async {
    if (_exportInterstitialShowing || !_canPresentExportAd) return;
    if (_exportInterstitial == null) {
      // Never wait: the render is done and its file is on screen. A request
      // that lands later is kept for the next render, not shown over this.
      if (!(_exportInterstitialRetry?.isActive ?? false)) {
        preloadExportInterstitial();
      }
      return;
    }
    _exportInterstitialShowing = true;
    try {
      await _presentExportInterstitial();
    } finally {
      _exportInterstitialShowing = false;
    }
  }

  bool get _canPresentExportAd {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return !_disposed &&
        _enabled() &&
        !_fullScreen &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  Future<void> _presentExportInterstitial() async {
    final ad = _exportInterstitial;
    if (ad == null) return;
    _exportInterstitial = null;
    final loadedAt = _exportInterstitialLoadedAt;
    _exportInterstitialLoadedAt = null;
    if (loadedAt == null ||
        _now().difference(loadedAt) >= const Duration(hours: 1)) {
      ad.dispose();
      preloadExportInterstitial();
      return;
    }
    final dismissed = Completer<void>();
    void ended() {
      if (dismissed.isCompleted) return;
      ad.dispose();
      _fullScreen = false;
      preloadExportInterstitial();
      dismissed.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) =>
          debugPrint('AdMob: export interstitial displayed'),
      onAdDismissedFullScreenContent: (_) => ended(),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('AdMob: export interstitial show failed — $error');
        ended();
      },
    );
    _fullScreen = true;
    try {
      await ad.show();
    } catch (error) {
      debugPrint('AdMob: export interstitial show failed — $error');
      ended();
    }
    await dismissed.future;
  }

  void dispose() {
    _disposed = true;
    _appOpenRetry?.cancel();
    _exportInterstitialRetry?.cancel();
    _exportLoadFinished();
    _exportInterstitial?.dispose();
    _exportInterstitial = null;
    _appOpen?.dispose();
    _appOpen = null;
  }

  @override
  Future<bool> privacyOptionsRequired() async {
    if (_units == null) return false;
    await _ensureReady();
    return await ConsentInformation.instance
            .getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  @override
  Future<void> showPrivacyOptions() {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) => done.complete());
    return done.future;
  }
}

/// Why an ad didn't load — no fill, no network, a wrong unit.
void _logFailure(String kind, LoadAdError error) => debugPrint(
  'AdMob: $kind ad failed to load — ${error.domain}/${error.code}: ${error.message}',
);

/// The native ad layout registered by the platform code —
/// `LastReelNativeAdFactory` in ios/Runner/NativeAdFactory.swift and
/// android/…/NativeAdFactory.kt: the design's ad row on a rounded card.
const nativeCardFactoryId = 'lastreelCard';

/// The palette as the native card reads it: "#RRGGBB" per role.
Map<String, Object> nativeCardColours(EcPalette p) {
  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  return {
    'surface': hex(p.surface),
    'line': hex(p.line),
    'tint': hex(p.tint),
    'ink': hex(p.ink),
    'muted': hex(p.muted),
    'onInk': hex(p.onInk),
  };
}

/// Which of the card's layouts the platform factory draws. The phone row
/// is the factory's default. Only Android draws the tablet shapes; iOS
/// keeps its row until iPad ships (§1).
Map<String, Object> nativeCardLayout(AdSlotStyle style, EcPalette p) {
  if (style.layout == AdLayout.row ||
      defaultTargetPlatform != TargetPlatform.android) {
    return const {};
  }
  // "#AARRGGBB": the "Ad" tag's ink and the still's translucent strong line.
  String argb(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  return {
    'layout': switch (style.layout) {
      AdLayout.compact => 'compact',
      _ => style.portrait ? 'stripPortrait' : 'strip',
    },
    'ink2': argb(p.ink2),
    'line2': argb(p.line2),
  };
}

/// A native ad on the app's own card (see [nativeCardFactoryId]). Shows
/// nothing until the ad has loaded — at most the space [AdSlotStyle.reserve]
/// keeps for it — and nothing if it never does.
class _NativeAdView extends StatefulWidget {
  final Future<NativeAd?> Function(
    Map<String, Object> colours,
    NativeAdListener listener,
  )
  load;
  final Widget Function(Widget creative) framed;
  final AdSlotStyle style;

  const _NativeAdView({
    super.key,
    required this.load,
    required this.framed,
    required this.style,
  });

  @override
  State<_NativeAdView> createState() => _NativeAdViewState();
}

class _NativeAdViewState extends State<_NativeAdView> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _started = false;
  bool _loading = false;
  bool _failed = false;
  int _attempts = 0;
  Timer? _retry;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (!_loaded && !_loading) {
          _attempts = 0;
          _load();
        }
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    if (!mounted || _loading || _loaded) return;
    _retry?.cancel();
    _loading = true;
    _attempts++;
    var failed = false;
    try {
      final ad = await widget.load(
        {
          ...nativeCardColours(context.palette),
          ...nativeCardLayout(widget.style, context.palette),
        },
        NativeAdListener(
          onAdLoaded: (ad) {
            if (!mounted) return;
            _loading = false;
            setState(() {
              _ad = ad as NativeAd;
              _loaded = true;
            });
            widget.style.onShown?.call();
            debugPrint('AdMob: native ad loaded');
          },
          onAdClicked: (_) => widget.style.onTapped?.call(),
          onAdFailedToLoad: (ad, error) {
            failed = true;
            _logFailure('native', error);
            ad.dispose();
            if (!mounted) return;
            _loading = false;
            _ad = null;
            _retryLater();
          },
        ),
      );
      if (!mounted) {
        if (!failed) ad?.dispose();
        return;
      }
      if (failed) return;
      _ad = ad;
      if (ad == null) {
        _loading = false;
        _retryLater();
      }
    } catch (error) {
      if (!mounted) return;
      _loading = false;
      debugPrint('AdMob: native request failed — $error');
      _retryLater();
    }
  }

  void _retryLater() {
    if (!mounted) return;
    // Nothing filled the slot: close up the reserved space, quietly.
    if (!_failed) {
      setState(() => _failed = true);
      widget.style.onEmpty?.call();
    }
    if (_attempts >= AdRetryPolicy.maxAttempts) return;
    _retry?.cancel();
    _retry = Timer(AdRetryPolicy.delay(_attempts), _load);
  }

  @override
  void dispose() {
    _retry?.cancel();
    _lifecycle.dispose();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) {
      final reserve = widget.style.reserve;
      return reserve == null || _failed
          ? const SizedBox.shrink()
          : SizedBox(height: reserve);
    }
    // The tablet shapes fill the card the slot draws around them; the
    // phone row draws its own rounded corners natively.
    final creative =
        widget.style.layout == AdLayout.row ||
            defaultTargetPlatform != TargetPlatform.android
        ? SizedBox(height: 76, child: AdWidget(ad: ad))
        : AdWidget(ad: ad);
    return widget.framed(creative);
  }
}
