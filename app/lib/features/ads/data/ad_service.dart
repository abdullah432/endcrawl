import 'package:flutter/widgets.dart';

import '../../../core/widgets/ec_ad_slot.dart';
import '../widgets/tablet_ad.dart';

/// Where a native ad sits. The free plan has exactly these, plus the
/// opt-in rewarded ad on 6.1a and an interstitial once a render succeeds —
/// one per screen, at its edge: never over the roll, the monitor, the
/// scrubber or a field, nor the template picker, a failed render or the file.
enum AdPlacement {
  /// The foot of the library (1.1, 1.2).
  library(
    'Filmsupply — 60% off first licence',
    'Stock footage for indie cuts.',
  ),


  /// Its own card under the block list, apart from the dock (T3.1, P3.1).
  /// Hidden while the keyboard is up.
  editor('Filmsupply — 60% off first licence', 'Stock footage for indie cuts.'),

  /// Under the Timing & Look panel, in the same place on both tabs so
  /// switching moves nothing (T5.1, T5.2, P5.1, P5.2).
  timingLook('Musicbed — Songs cleared for festival cuts', 'Music licensing for filmmakers'),

  /// At the foot of tablet export settings (6.1).
  exportSettings('Artlist — royalty-free score', 'Music licensing for filmmakers'),

  /// While a render encodes (6.2).
  rendering(
    'Artlist — royalty-free score',
    'Static, silent, gone when the render ends.',
  ),

  /// Below the destinations once the file has saved (6.4).
  exportComplete(
    'Soundstripe — score your next cut',
    'Music licensing for filmmakers',
  );

  /// House copy for where no ad network is wired in.
  final String houseHeadline;
  final String houseBody;
  const AdPlacement(this.houseHeadline, this.houseBody);
}

/// How a native ad is drawn.
enum AdLayout {
  /// The phone's row (1.1, 6.2): icon, headline, "Ad" and body, a pill.
  row,

  /// The tablet library's foot strip (T8.1, P1.2): a 16:9 image, the "Ad"
  /// tag and advertiser, the headline, a line of body and the action.
  strip,

  /// The tablet Settings card (T7.1, P7.1): "Ad" over a 72 × 56 image
  /// and the headline.
  compact,
}

/// The shape of one slot, and what it reports (`ad_slot_shown`,
/// `ad_slot_empty`, `ad_tapped`).
class AdSlotStyle {
  final AdLayout layout;

  /// Portrait strips (P1.2) put "Remove ads" under the headline rather
  /// than under the action.
  final bool portrait;

  /// The height the slot keeps for its ad while it loads, so nothing
  /// moves when it arrives. The slot closes up if no ad fills it.
  final double? reserve;

  final VoidCallback? onShown;
  final VoidCallback? onEmpty;
  final VoidCallback? onTapped;

  const AdSlotStyle({
    this.layout = AdLayout.row,
    this.portrait = false,
    this.reserve,
    this.onShown,
    this.onEmpty,
    this.onTapped,
  });
}

/// How a rewarded ad ended.
enum RewardOutcome {
  /// Watched to the end: the reward is earned.
  earned,

  /// Closed before the reward: nothing is unlocked.
  closedEarly,

  /// No ad to show (no fill, offline, consent refused).
  unavailable,
}

/// The ad network, behind one seam: screens ask for a placement's native
/// ad or for a rewarded ad and never see the SDK.
///
/// Only ever called on the free plan; callers check the entitlement first.
abstract interface class AdService {
  /// A native ad for [placement], drawn as [style] and wrapped by
  /// [framed] (the "Sponsored" label, or the tablet card, and the way out
  /// to Pro). Nothing at all — frame included — while there's no ad, so a
  /// slot never shows an empty frame; at most the space [style] reserves.
  Widget nativeAd(
    AdPlacement placement, {
    required Widget Function(Widget creative) framed,
    AdSlotStyle style = const AdSlotStyle(),
  });

  /// Shows a rewarded ad full screen — only ever because the user asked
  /// for it. Completes when it's dismissed.
  Future<RewardOutcome> showRewarded();

  /// Shows the app-open ad if one is loaded, and loads the next. Called
  /// only when the app returns from the background.
  Future<void> showAppOpen();

  /// Loads an app-open ad ahead of time, so the first return from the
  /// background has one ready. Shows nothing.
  void preloadAppOpen();

  /// Preloads a standard interstitial ahead of a render finishing.
  void preloadExportInterstitial();

  /// Shows a ready ad after success. Never waits for inventory to load.
  Future<void> showExportInterstitial();

  /// An ad covers the app right now. A render keeps going behind it, even
  /// though the app is briefly inactive.
  bool get showingFullScreen;

  /// Whether the consent framework asks for an "Ad privacy choices" entry
  /// in settings, and showing it.
  Future<bool> privacyOptionsRequired();
  Future<void> showPrivacyOptions();
}

/// House creatives and no rewarded inventory — for tests and previews.
class PlaceholderAdService implements AdService {
  const PlaceholderAdService();

  @override
  Widget nativeAd(
    AdPlacement placement, {
    required Widget Function(Widget creative) framed,
    AdSlotStyle style = const AdSlotStyle(),
  }) => framed(switch (style.layout) {
    AdLayout.row => EcAdPlaceholder(headline: placement.houseHeadline, body: placement.houseBody),
    _ => TabletAdPlaceholder(placement: placement, layout: style.layout, portrait: style.portrait),
  });

  @override
  Future<RewardOutcome> showRewarded() async => RewardOutcome.unavailable;

  @override
  Future<void> showAppOpen() async {}

  @override
  void preloadAppOpen() {}

  @override
  void preloadExportInterstitial() {}

  @override
  Future<void> showExportInterstitial() async {}

  @override
  bool get showingFullScreen => false;

  @override
  Future<bool> privacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}
