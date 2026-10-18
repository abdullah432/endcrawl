import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/release_config.dart';
import '../../../domain/models/entitlement.dart';
import '../../access/controllers/web_access.dart';

/// Native iPhone/iPad launch policy, regardless of window size. A browser
/// reporting iOS still uses the existing web access rules.
final iosFreeLaunchProvider = Provider<bool>((ref) {
  return ref.watch(iosFreeLaunchFlagProvider) &&
      !ref.watch(runningOnWebProvider) &&
      defaultTargetPlatform == TargetPlatform.iOS;
});

/// Project access is independent of Pro's ad and rewarded-export benefits.
final projectLimitProvider = Provider<int?>((ref) {
  if (ref.watch(iosFreeLaunchProvider)) return null;
  return (ref.watch(entitlementProvider).value ?? const Entitlement.free())
      .projectLimit;
});
