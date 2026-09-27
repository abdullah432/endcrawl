import '../../core/result.dart';

/// What the signed-in account is allowed, by plan.
///
/// The whole difference between Free and Pro, in one place: Pro lifts the
/// three-project cap, removes ads, and renders the master formats (ProRes,
/// PNG, 4K) every time — on Free each one takes a rewarded ad. Every block,
/// timing and look tool is on both plans.
enum Plan { free, pro }

enum BillingPeriod { monthly, yearly }

class Entitlement {
  static const freeProjectLimit = 3;

  final Plan plan;

  /// Set for Pro: how it's billed and when it renews (7.3).
  final BillingPeriod? period;
  final DateTime? renewsAt;
  final bool willRenew;
  final Uri? managementUrl;

  const Entitlement.free() : plan = Plan.free, period = null, renewsAt = null, willRenew = false, managementUrl = null;

  const Entitlement.pro({this.period, this.renewsAt, this.willRenew = true, this.managementUrl}) : plan = Plan.pro;

  bool get isPro => plan == Plan.pro;

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

  const PlanOffer({
    required this.period,
    required this.price,
    required this.detail,
    this.badge,
    required this.packageId,
  });
}

/// Returned when an action would add a project beyond the plan's cap. A
/// sentinel (compared by identity) so the UI can route it to the "slots
/// full" sheet (1.6) rather than showing it as an error.
const slotsFull = AppFailure(FailureKind.permission, 'All three free slots are in use.');

bool isSlotsFull(AppFailure failure) => identical(failure, slotsFull);
