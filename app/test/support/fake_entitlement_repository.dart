import 'package:lastreel/core/result.dart';
import 'package:lastreel/data/repositories/entitlement_repository.dart';
import 'package:lastreel/domain/models/entitlement.dart';

/// A plan source whose plan a test chooses.
class FakeEntitlementRepository implements EntitlementRepository {
  Entitlement entitlement;
  int purchases = 0;

  FakeEntitlementRepository([this.entitlement = const Entitlement.free()]);

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
