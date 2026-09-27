import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import '../../core/config/billing_config.dart';
import '../../core/result.dart';
import '../../domain/models/entitlement.dart';
import 'entitlement_repository.dart';

/// Owns the process-wide SDK. Identity changes and store operations are serialized
/// so a late purchase/login cannot grant Pro to a different signed-in account.
class RevenueCatEntitlementRepository with WidgetsBindingObserver implements EntitlementRepository {
  RevenueCatEntitlementRepository({required this.apiKey}) {
    WidgetsBinding.instance.addObserver(this);
    rc.Purchases.addCustomerInfoUpdateListener(_customerInfoChanged);
  }

  final String apiKey;
  final _updates = StreamController<Entitlement>.broadcast();
  Future<void> _tail = Future.value();
  String? _uid;
  String? _sdkUid;
  int _generation = 0;
  bool _disposed = false;
  Entitlement _current = const Entitlement.free();
  final Map<String, rc.Package> _packages = {};

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void setUser(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
    _generation++;
    _packages.clear();
    _publish(const Entitlement.free());
    unawaited(refresh());
  }

  bool _valid(int generation) => !_disposed && generation == _generation;

  Future<void> _identify() async {
    final uid = _uid;
    if (uid == null) {
      if (await rc.Purchases.isConfigured && _sdkUid != null) {
        await rc.Purchases.logOut();
        _sdkUid = null;
      }
      return;
    }
    if (!await rc.Purchases.isConfigured) {
      await rc.Purchases.configure(rc.PurchasesConfiguration(apiKey)..appUserID = uid);
    } else if (_sdkUid != uid) {
      await rc.Purchases.logIn(uid);
    }
    _sdkUid = uid;
  }

  Future<void> refresh() async {
    final generation = _generation;
    try {
      await _serial(() async {
        if (!_valid(generation)) return;
        await _identify();
        if (_uid == null || !_valid(generation)) return;
        final info = await rc.Purchases.getCustomerInfo();
        if (_valid(generation)) _publish(entitlementFromCustomerInfo(info));
      });
    } catch (_) {
      // Keep the last SDK-verified plan on transient failures. A new account
      // has already been reset to Free by setUser.
    }
  }

  void _customerInfoChanged(rc.CustomerInfo _) {
    // Read again after queued identity changes, rather than trusting a callback
    // potentially emitted for the account that was just signed out.
    unawaited(refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  void _publish(Entitlement value) {
    if (_disposed) return;
    _current = value;
    _updates.add(value);
  }

  @override
  Stream<Entitlement> watch() => Stream.multi((controller) {
    controller.add(_current);
    final subscription = _updates.stream.listen(controller.add);
    controller.onCancel = subscription.cancel;
  });

  Future<Result<T>> _run<T>(Future<T> Function() action) {
    final generation = _generation;
    return _serial(() async {
      try {
        if (!_valid(generation) || _uid == null) {
          throw const AppFailure(FailureKind.permission, 'Sign in to manage your subscription.');
        }
        await _identify();
        if (!_valid(generation)) throw _accountChanged;
        final value = await action();
        if (!_valid(generation)) throw _accountChanged;
        return Ok(value);
      } on AppFailure catch (failure) {
        return Err(failure);
      } on PlatformException catch (error) {
        return Err(billingFailure(error));
      } catch (_) {
        return const Err(AppFailure(FailureKind.unknown, 'The store is unavailable. Please try again.'));
      }
    });
  }

  static const _accountChanged = AppFailure(FailureKind.permission, 'Your account changed. Please try again.');

  @override
  Future<Result<List<PlanOffer>>> offers() => _run(() async {
    final offering = (await rc.Purchases.getOfferings()).current;
    final packages =
        offering?.availablePackages
            .where((p) => p.packageType == rc.PackageType.monthly || p.packageType == rc.PackageType.annual)
            .toList() ??
        [];
    if (packages.isEmpty) {
      throw const AppFailure(
        FailureKind.notFound,
        'Subscriptions are not available from the store yet. Please try again later.',
      );
    }
    _packages.clear();
    return packages.map((p) {
      _packages[p.identifier] = p;
      return PlanOffer(
        period: p.packageType == rc.PackageType.annual ? BillingPeriod.yearly : BillingPeriod.monthly,
        price: p.storeProduct.priceString,
        detail: p.packageType == rc.PackageType.annual
            ? 'Billed yearly · Cancel anytime'
            : 'Billed monthly · Cancel anytime',
        packageId: p.identifier,
      );
    }).toList();
  });

  @override
  Future<Result<Entitlement>> purchase(PlanOffer offer) async {
    final generation = _generation;
    final result = await _run(() async {
      final package = _packages[offer.packageId];
      if (package == null || package.storeProduct.priceString != offer.price) {
        throw const AppFailure(FailureKind.notFound, 'Reload the plans before purchasing.');
      }
      final info = await rc.Purchases.getCustomerInfo();
      if (entitlementFromCustomerInfo(info).isPro) {
        throw const AppFailure(
          FailureKind.permission,
          'You already have Pro. Manage your plan in your store subscriptions.',
        );
      }
      if (!_valid(generation)) throw _accountChanged;
      final purchase = await rc.Purchases.purchase(rc.PurchaseParams.package(package));
      final entitlement = entitlementFromCustomerInfo(purchase.customerInfo);
      if (!entitlement.isPro) {
        throw const AppFailure(
          FailureKind.unknown,
          'Your purchase is being processed. Restore purchases if Pro does not appear.',
        );
      }
      return entitlement;
    });
    if (_valid(generation) && result is Ok<Entitlement>) _publish(result.value);
    return result;
  }

  @override
  Future<Result<Entitlement>> restore() async {
    final generation = _generation;
    final result = await _run(() async => entitlementFromCustomerInfo(await rc.Purchases.restorePurchases()));
    if (_valid(generation) && result is Ok<Entitlement>) _publish(result.value);
    return result;
  }

  void dispose() {
    _disposed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    rc.Purchases.removeCustomerInfoUpdateListener(_customerInfoChanged);
    unawaited(_updates.close());
  }
}

Entitlement entitlementFromCustomerInfo(rc.CustomerInfo info) {
  final pro = info.entitlements.active[BillingConfig.entitlementId];
  if (pro == null || !pro.isActive || pro.verification == rc.VerificationResult.failed) return const Entitlement.free();
  final plan = pro.productPlanIdentifier ?? pro.productIdentifier.split(':').last;
  final period = switch (plan) {
    'monthly' || 'lastreel_pro_monthly' => BillingPeriod.monthly,
    'yearly' || 'annual' || 'lastreel_pro_yearly' => BillingPeriod.yearly,
    _ => null,
  };
  return Entitlement.pro(
    period: period,
    renewsAt: pro.expirationDate == null ? null : DateTime.tryParse(pro.expirationDate!),
    willRenew: pro.willRenew,
    managementUrl: info.managementURL == null ? null : Uri.tryParse(info.managementURL!),
  );
}

AppFailure billingFailure(PlatformException error) {
  final code = rc.PurchasesErrorHelper.getErrorCode(error);
  return switch (code) {
    rc.PurchasesErrorCode.purchaseCancelledError => const AppFailure(FailureKind.cancelled, ''),
    rc.PurchasesErrorCode.paymentPendingError => const AppFailure(
      FailureKind.unknown,
      'Payment is pending. Pro will unlock when your store confirms payment.',
    ),
    rc.PurchasesErrorCode.networkError => const AppFailure(
      FailureKind.network,
      'Could not reach the store. Check your connection and try again.',
    ),
    rc.PurchasesErrorCode.purchaseNotAllowedError => const AppFailure(
      FailureKind.permission,
      'Purchases are not allowed on this store account.',
    ),
    rc.PurchasesErrorCode.productAlreadyPurchasedError => const AppFailure(
      FailureKind.unknown,
      'You already own this subscription. Try Restore purchases.',
    ),
    _ => const AppFailure(FailureKind.unknown, 'Could not complete the store request. Please try again.'),
  };
}
