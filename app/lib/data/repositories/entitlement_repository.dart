import '../../core/result.dart';
import '../../domain/models/entitlement.dart';

/// Where the plan comes from.
///
/// Implemented by RevenueCat on supported, configured stores.
/// Everything above reads [watch] and calls [purchase] / [restore]; swapping
/// in the store-backed implementation changes nothing else. The plan is
/// never read from Firestore — a client-writable plan is one anyone can
/// grant themselves.
abstract interface class EntitlementRepository {
  Stream<Entitlement> watch();

  Future<Result<List<PlanOffer>>> offers();

  Future<Result<Entitlement>> purchase(PlanOffer offer);

  Future<Result<Entitlement>> restore();
}

/// Everyone is on Free until billing is wired in.
///
/// Purchase and restore answer honestly instead of pretending: purchases
/// aren't available in this build, and there's nothing to restore.
class FreeEntitlementRepository implements EntitlementRepository {
  const FreeEntitlementRepository();

  static const unavailable = AppFailure(
    FailureKind.unknown,
    'Purchases aren’t available in this build yet. You can keep using the Free plan.',
  );

  @override
  Future<Result<List<PlanOffer>>> offers() async => const Err(unavailable);

  @override
  Stream<Entitlement> watch() => Stream.value(const Entitlement.free());

  @override
  Future<Result<Entitlement>> purchase(PlanOffer offer) async => const Err(unavailable);

  @override
  Future<Result<Entitlement>> restore() async =>
      const Err(AppFailure(FailureKind.notFound, 'Purchases are not configured for this platform yet.'));
}
