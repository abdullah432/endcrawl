import 'package:flutter/widgets.dart';

import '../../../core/widgets/ec_ad_slot.dart';

/// Where a native ad sits. The free plan has exactly these, plus the
/// opt-in rewarded ad on 6.1a — never the editor, the monitor, the
/// template picker, a failed render, or the exported file.
enum AdPlacement {
  /// The foot of the library (1.1, 1.2).
  library('Filmsupply — 60% off first licence', 'Stock footage for indie cuts.'),

  /// While a render encodes (6.2).
  rendering('Artlist — royalty-free score', 'Static, silent, gone when the render ends.'),

  /// Below the destinations once the file has saved (6.4).
  exportComplete('Soundstripe — score your next cut', 'Music licensing for filmmakers');

  /// House copy for where no ad network is wired in.
  final String houseHeadline;
  final String houseBody;
  const AdPlacement(this.houseHeadline, this.houseBody);
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
  /// A native ad for [placement]. Collapses to nothing when there's no ad,
  /// so a slot never shows an empty frame.
  Widget nativeAd(AdPlacement placement);

  /// Shows a rewarded ad full screen — only ever because the user asked
  /// for it. Completes when it's dismissed.
  Future<RewardOutcome> showRewarded();

  /// Whether the consent framework asks for an "Ad privacy choices" entry
  /// in settings, and showing it.
  Future<bool> privacyOptionsRequired();
  Future<void> showPrivacyOptions();
}

/// House creatives and no rewarded inventory — for tests and previews.
class PlaceholderAdService implements AdService {
  const PlaceholderAdService();

  @override
  Widget nativeAd(AdPlacement placement) =>
      EcAdPlaceholder(headline: placement.houseHeadline, body: placement.houseBody);

  @override
  Future<RewardOutcome> showRewarded() async => RewardOutcome.unavailable;

  @override
  Future<bool> privacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}
