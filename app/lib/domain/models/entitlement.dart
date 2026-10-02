import '../../core/result.dart';
import '../../core/utils/formatting.dart';

/// What the signed-in account is allowed, by plan.
///
/// The whole difference between Free and Pro, in one place: Pro lifts the
/// two-project cap, removes ads, and renders the master formats (ProRes,
/// PNG, 4K) every time — on Free each one takes a rewarded ad. Every block,
/// timing and look tool is on both plans. A free trial is Pro in full.
enum Plan { free, pro }

enum BillingPeriod { monthly, yearly }

class Entitlement {
  /// The free plan's project cap — the one number every "2 of 2", meter
  /// and slots-full sheet reads.
  static const freeProjectLimit = 2;

  /// "two projects" — the cap as copy says it.
  static String get freeProjectsInWords => '${numberWord(freeProjectLimit)} ${freeProjectLimit == 1 ? 'project' : 'projects'}';

  final Plan plan;

  /// Set for Pro: how it's billed and when it renews (7.3).
  final BillingPeriod? period;
  final DateTime? renewsAt;
  final bool willRenew;
  final Uri? managementUrl;

  /// Set while Pro is a free trial: when it ends.
  final DateTime? trialEndsAt;

  /// Free after having had Pro (a trial or a subscription that ended).
  final bool lapsed;

  const Entitlement.free({this.lapsed = false})
    : plan = Plan.free,
      period = null,
      renewsAt = null,
      willRenew = false,
      managementUrl = null,
      trialEndsAt = null;

  const Entitlement.pro({this.period, this.renewsAt, this.willRenew = true, this.managementUrl, this.trialEndsAt})
    : plan = Plan.pro,
      lapsed = false;

  bool get isPro => plan == Plan.pro;
  bool get isTrial => isPro && trialEndsAt != null;

  /// Whole days left in the trial, counting a part day as a day — "6 days
  /// left" until the last day, which reads "1 day left".
  int? trialDaysLeft(DateTime now) {
    final ends = trialEndsAt;
    if (!isTrial || ends == null) return null;
    final left = ends.difference(now);
    if (left <= Duration.zero) return 0;
    return (left.inSeconds / Duration.secondsPerDay).ceil();
  }

  /// Null means unlimited.
  int? get projectLimit => isPro ? null : freeProjectLimit;

  bool get showsAds => !isPro;

  /// Whether one more project fits, given how many exist.
  bool canAddProject(int existing) => projectLimit == null || existing < projectLimit!;

  /// Free slots left, or null when unlimited.
  int? slotsLeft(int existing) => projectLimit == null ? null : (projectLimit! - existing).clamp(0, projectLimit!);
}

/// A purchasable Pro option as the paywall (6.5) lists it.
class PlanOffer {
  final BillingPeriod period;
  final String price;
  final String detail;
  final String? badge;
  final String packageId;

  /// The free trial this account would get, in days; null when there's
  /// none — no trial on the product, or the account has had one.
  final int? trialDays;

  /// The price as a monthly figure, for "then \$2.50 a month".
  final String? pricePerMonth;

  const PlanOffer({
    required this.period,
    required this.price,
    required this.detail,
    this.badge,
    required this.packageId,
    this.trialDays,
    this.pricePerMonth,
  });

  bool get hasTrial => (trialDays ?? 0) > 0;

  /// "/yr", "/mo".
  String get perPeriod => period == BillingPeriod.yearly ? '/yr' : '/mo';

  /// "Start 14-day free trial", or the plain price without a trial.
  String get ctaLabel => hasTrial ? 'Start $trialDays-day free trial' : 'Start Pro — $price$perPeriod';

  /// "14 days free, then \$2.50 a month" / "7 days free, then \$4.99/mo".
  String get trialSubtitle {
    final then = period == BillingPeriod.yearly && pricePerMonth != null ? '$pricePerMonth a month' : '$price$perPeriod';
    return hasTrial ? '$trialDays days free, then $then' : detail;
  }
}

/// Returned when an action would add a project beyond the plan's cap. A
/// sentinel (compared by identity) so the UI can route it to the "slots
/// full" sheet (1.6) rather than showing it as an error.
const slotsFull = AppFailure(FailureKind.permission, 'Your free project slots are in use.');

bool isSlotsFull(AppFailure failure) => identical(failure, slotsFull);
