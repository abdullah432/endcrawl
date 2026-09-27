import 'package:lastreel/core/result.dart';
import 'package:lastreel/data/repositories/entitlement_repository.dart';
import 'package:lastreel/domain/models/entitlement.dart';

/// A plan source whose plan a test chooses.
class FakeEntitlementRepository implements EntitlementRepository {
  Entitlement entitlement;
  int purchases = 0;

  FakeEntitlementRepository([this.entitlement = const Entitlement.free()]);

  @override
  Future<Result<List<PlanOffer>>> offers() async => const Ok([
    PlanOffer(period: BillingPeriod.monthly, price: r'$4.99', detail: 'Billed monthly', packageId: r'$rc_monthly'),
    PlanOffer(period: BillingPeriod.yearly, price: r'$29.99', detail: 'Billed yearly', packageId: r'$rc_annual'),
  ]);

  @override
  Stream<Entitlement> watch() => Stream.value(entitlement);

  @override
  Future<Result<Entitlement>> purchase(PlanOffer offer) async {
    purchases++;
    return const Err(FreeEntitlementRepository.unavailable);
  }

  @override
  Future<Result<Entitlement>> restore() async => Ok(entitlement);
}
