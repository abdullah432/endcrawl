import '../../core/result.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctionsException;
import 'package:flutter/foundation.dart' show debugPrint;
import '../../domain/models/entitlement.dart';
import 'entitlement_repository.dart';
import 'web_billing_repository.dart';

/// Hosted checkout adds purchases to the existing server-verified entitlement source.
class WebCheckoutEntitlementRepository implements EntitlementRepository {
  final EntitlementRepository access;
  final WebBillingRepository billing;
  final Future<bool> Function(Uri) navigate;
  final bool Function() isCurrent;
  WebCheckoutEntitlementRepository({
    required this.access,
    required this.billing,
    required this.navigate,
    required this.isCurrent,
  });
  @override
  Stream<Entitlement> watch() => access.watch();
  @override
  Future<Result<Entitlement>> restore() => access.restore();
  @override
  Future<Result<List<PlanOffer>>> offers() async {
    try {
      final catalog = await billing.catalog();
      if (!isCurrent()) {
        return const Err(
          AppFailure(FailureKind.cancelled, 'Your account changed.'),
        );
      }
      return catalog.enabled && catalog.offers.isNotEmpty
          ? Ok(catalog.offers)
          : const Err(
              AppFailure(
                FailureKind.notFound,
                'Web subscriptions are not available for this account yet.',
              ),
            );
    } catch (_) {
      return const Err(
        AppFailure(
          FailureKind.network,
          'Could not load plans. Please try again.',
        ),
      );
    }
  }

  @override
  Future<Result<Entitlement>> purchase(PlanOffer offer) async {
    try {
      final uri = await billing.checkout(offer.period);
      if (!isCurrent()) {
        return const Err(
          AppFailure(FailureKind.cancelled, 'Your account changed.'),
        );
      }
      if (!await navigate(uri)) {
        return const Err(
          AppFailure(
            FailureKind.network,
            'Could not open checkout. Please try again.',
          ),
        );
      }
      // The redirect is only navigation: the access repository alone emits Pro.
      return const Ok(Entitlement.checking());
    } on FirebaseFunctionsException catch (error) {
      return Err(
        AppFailure(
          FailureKind.network,
          error.message ?? 'Could not open checkout. Please try again.',
          cause: error,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Web checkout navigation failed: ${error.runtimeType}.');
      return Err(
        AppFailure(
          FailureKind.network,
          'Could not open checkout. Please try again.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
