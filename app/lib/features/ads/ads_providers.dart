import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap.dart';
import 'data/ad_service.dart';
import 'data/admob_ad_service.dart';

/// AdMob in the app; tests override it with a fake.
final adServiceProvider = Provider<AdService>((ref) {
  return AdMobAdService(() => ref.read(userProfileProvider).value?.preferences.personalisedAds ?? false);
});

/// Whether 7.4 needs its "Ad privacy choices" row — only where the consent
/// framework requires one, and never on Pro.
final adPrivacyOptionsRequiredProvider = FutureProvider<bool>((ref) async {
  final showsAds = ref.watch(entitlementProvider).value?.showsAds ?? false;
  return showsAds && await ref.watch(adServiceProvider).privacyOptionsRequired();
});
