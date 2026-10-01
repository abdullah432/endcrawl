import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../domain/models/entitlement.dart';

/// Logs the end of the trial funnel from plan changes the app sees:
/// `trial_converted` when a trial becomes paid Pro, `trial_cancelled` when
/// a running trial stops renewing. Watched from the app root.
///
/// The app only sees changes while it runs, so these are a client-side
/// view; RevenueCat's own Firebase integration reports conversions and
/// cancellations from the store and is the authoritative source.
final trialAnalyticsProvider = Provider<void>((ref) {
  ref.listen<Entitlement?>(entitlementProvider.select((e) => e.value), (previous, next) {
    if (previous == null || next == null || !previous.isTrial) return;
    final analytics = ref.read(analyticsProvider);
    final plan = {if (next.period ?? previous.period case final period?) 'plan': period.name};
    if (next.isPro && !next.isTrial) {
      analytics.logEvent('trial_converted', plan);
    } else if (next.isTrial && previous.willRenew && !next.willRenew) {
      analytics.logEvent('trial_cancelled', plan);
    }
  });
});
