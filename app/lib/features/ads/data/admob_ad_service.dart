import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/ad_config.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
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

  Future<bool>? _ready;
  AppOpenAd? _appOpen;
  DateTime? _appOpenLoadedAt;
  bool _fullScreen = false;

  /// [_personalised] reads the user's personalised-ads choice at request time.
  AdMobAdService(this._personalised, {AdUnits? units}) : _units = units ?? AdUnits.current;

  /// Consent, then the SDK. False when ads can't be requested — no units
  /// for this platform, or consent not given.
  Future<bool> _ensureReady() => _ready ??= _start();

  Future<bool> _start() async {
    if (_units == null) return false;
    final consent = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) => consent.complete()),
      (_) => consent.complete(),
    );
    await consent.future;
    if (!await ConsentInformation.instance.canRequestAds()) {
      _ready = null; // ask again next time; consent may change
      return false;
    }
    await MobileAds.instance.initialize();
    return true;
  }

  AdRequest get _request => AdRequest(nonPersonalizedAds: !_personalised());

  String _nativeUnit(AdPlacement placement) => switch (placement) {
        AdPlacement.library => _units!.libraryNative,
        AdPlacement.rendering => _units!.renderingNative,
        AdPlacement.exportComplete => _units!.exportReadyNative,
      };

  @override
  Widget nativeAd(AdPlacement placement, {required Widget Function(Widget creative) framed}) {
    if (_units == null) return const SizedBox.shrink();
    return _NativeAdView(
      key: ValueKey(placement),
      load: (style, listener) async {
        if (!await _ensureReady()) return null;
        final ad = NativeAd(
          adUnitId: _nativeUnit(placement),
          request: _request,
          listener: listener,
          nativeTemplateStyle: style,
        );
        await ad.load();
        return ad;
      },
      framed: framed,
    );
  }

  @override
  Future<RewardOutcome> showRewarded() async {
    if (!await _ensureReady()) return RewardOutcome.unavailable;
    final loaded = Completer<RewardedInterstitialAd?>();
    await RewardedInterstitialAd.load(
      adUnitId: _units!.proRenderRewarded,
      request: _request,
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: loaded.complete,
        onAdFailedToLoad: (_) => loaded.complete(null),
      ),
    );
    final ad = await loaded.future;
    if (ad == null) return RewardOutcome.unavailable;

    var earned = false;
    final ended = Completer<RewardOutcome>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _fullScreen = false;
        ended.complete(earned ? RewardOutcome.earned : RewardOutcome.closedEarly);
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
  Future<void> showAppOpen() async {
    if (_fullScreen || !await _ensureReady()) return;
    final ad = _appOpen;
    final fresh = _appOpenLoadedAt != null && DateTime.now().difference(_appOpenLoadedAt!) < AppOpenPolicy.maxAdAge;
    if (ad == null || !fresh) {
      ad?.dispose();
      _appOpen = null;
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

  /// Loads the next app-open ad ahead of time, so a resume shows it at once.
  void _loadAppOpen() {
    AppOpenAd.load(
      adUnitId: _units!.appOpenResume,
      request: _request,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpen = ad;
          _appOpenLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  @override
  Future<bool> privacyOptionsRequired() async {
    if (_units == null) return false;
    await _ensureReady();
    return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
  }

  @override
  Future<void> showPrivacyOptions() {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((_) => done.complete());
    return done.future;
  }
}

/// A native ad drawn with Google's small template in the app's colours.
/// Shows nothing until the ad has loaded, and nothing if it never does.
class _NativeAdView extends StatefulWidget {
  final Future<NativeAd?> Function(NativeTemplateStyle style, NativeAdListener listener) load;
  final Widget Function(Widget creative) framed;

  const _NativeAdView({super.key, required this.load, required this.framed});

  @override
  State<_NativeAdView> createState() => _NativeAdViewState();
}

class _NativeAdViewState extends State<_NativeAdView> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final p = context.palette;
    final style = NativeTemplateStyle(
      templateType: TemplateType.small,
      mainBackgroundColor: p.surface,
      cornerRadius: EcRadius.row,
      callToActionTextStyle: NativeTemplateTextStyle(textColor: p.onInk, backgroundColor: p.ink, size: 13),
      primaryTextStyle: NativeTemplateTextStyle(textColor: p.ink, size: 14),
      secondaryTextStyle: NativeTemplateTextStyle(textColor: p.muted, size: 12),
      tertiaryTextStyle: NativeTemplateTextStyle(textColor: p.muted, size: 12),
    );
    widget.load(
      style,
      NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    ).then((ad) {
      if (!mounted) {
        ad?.dispose();
        return;
      }
      setState(() => _ad = ad);
    });
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return widget.framed(
      ClipRRect(
        borderRadius: BorderRadius.circular(EcRadius.row),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 90, maxHeight: 120),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
