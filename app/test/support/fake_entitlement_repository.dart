import 'dart:async';

import 'package:lastreel/core/result.dart';
import 'package:lastreel/data/repositories/entitlement_repository.dart';
import 'package:lastreel/domain/models/entitlement.dart';

/// A plan source whose plan a test chooses — and can change mid-test.
class FakeEntitlementRepository implements EntitlementRepository {
  Entitlement _entitlement;
  final _changes = StreamController<Entitlement>.broadcast();

  /// Whether this account would get the store's free trials.
  bool trialEligible;

  /// When set, a purchase succeeds with this; otherwise purchases are
  /// unavailable, as in a build without a store.
  Entitlement? purchaseGrants;

  int purchases = 0;
  PlanOffer? lastPurchased;

  FakeEntitlementRepository([this._entitlement = const Entitlement.free(), this.trialEligible = true]);

  Entitlement get entitlement => _entitlement;

  set entitlement(Entitlement value) {
    _entitlement = value;
    _changes.add(value);
  }

  @override
  Future<Result<List<PlanOffer>>> offers() async => Ok([
    PlanOffer(
      period: BillingPeriod.monthly,
      price: r'$4.99',
      detail: 'Billed monthly',
      packageId: r'$rc_monthly',
      trialDays: trialEligible ? 7 : null,
      pricePerMonth: r'$4.99',
    ),
    PlanOffer(
      period: BillingPeriod.yearly,
      price: r'$29.99',
      detail: 'Billed yearly',
      packageId: r'$rc_annual',
      trialDays: trialEligible ? 14 : null,
      pricePerMonth: r'$2.50',
    ),
  ]);

  @override
  Stream<Entitlement> watch() => Stream.multi((controller) {
    controller.add(_entitlement);
    final sub = _changes.stream.listen(controller.add);
    controller.onCancel = sub.cancel;
  });

  @override
  Future<Result<Entitlement>> purchase(PlanOffer offer) async {
    purchases++;
    lastPurchased = offer;
    final grants = purchaseGrants;
    if (grants == null) return const Err(FreeEntitlementRepository.unavailable);
    entitlement = grants;
    return Ok(grants);
  }

  @override
  Future<Result<Entitlement>> restore() async => Ok(_entitlement);
}
