import '../../core/result.dart';
import '../../domain/models/entitlement.dart';

/// Where the plan comes from.
///
/// An interface because the real source is a store (StoreKit / Play
/// Billing, or RevenueCat on top of both) that doesn't exist in this build.
/// Everything above reads [watch] and calls [purchase] / [restore]; swapping
/// in the store-backed implementation changes nothing else. The plan is
/// never read from Firestore — a client-writable plan is one anyone can
/// grant themselves.
abstract interface class EntitlementRepository {
  Stream<Entitlement> watch();

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
    'Purchases aren’t available in this build yet. Everything in EndCrawl works on Free.',
  );

  @override
  Stream<Entitlement> watch() => Stream.value(const Entitlement.free());

  @override
  Future<Result<Entitlement>> purchase(PlanOffer offer) async => const Err(unavailable);

  @override
  Future<Result<Entitlement>> restore() async =>
      const Err(AppFailure(FailureKind.notFound, 'No purchases to restore on this Apple ID.'));
}
