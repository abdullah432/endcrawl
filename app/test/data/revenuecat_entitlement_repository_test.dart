import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/result.dart';
import 'package:lastreel/data/repositories/revenuecat_entitlement_repository.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

Map<String, dynamic> customer({
  bool pro = false,
  bool renews = true,
  String uid = 'a',
  String verification = 'NOT_REQUESTED',
  String periodType = 'NORMAL',
  bool everHadPro = true,
}) {
  final entitlement = <String, dynamic>{
    'identifier': 'pro',
    'isActive': pro,
    'willRenew': renews,
    'latestPurchaseDate': '2026-09-27T00:00:00Z',
    'originalPurchaseDate': '2026-09-27T00:00:00Z',
    'productIdentifier': 'lastreel_pro',
    'productPlanIdentifier': 'yearly',
    'isSandbox': true,
    'expirationDate': '2027-09-27T00:00:00Z',
    'verification': verification,
    'periodType': periodType,
  };
  return {
    'entitlements': {
      'all': {if (pro || everHadPro) 'pro': entitlement},
      'active': {if (pro) 'pro': entitlement},
    },
    'allPurchaseDates': <String, String>{},
    'activeSubscriptions': <String>[],
    'allPurchasedProductIdentifiers': <String>[],
    'nonSubscriptionTransactions': <dynamic>[],
    'firstSeen': '2026-09-27T00:00:00Z',
    'originalAppUserId': uid,
    'allExpirationDates': <String, String>{},
    'requestDate': '2026-09-27T00:00:00Z',
    'managementURL': 'https://play.google.com/store/account/subscriptions',
  };
}

Map<String, dynamic> offering() => {
  'identifier': 'default',
  'serverDescription': 'LastReel Pro',
  'metadata': <String, dynamic>{},
  'availablePackages': [
    {
      'identifier': r'$rc_annual',
      'packageType': 'ANNUAL',
      'presentedOfferingContext': {'offeringIdentifier': 'default'},
      'product': {
        'identifier': 'lastreel_pro:yearly',
        'description': 'Pro',
        'title': 'Pro',
        'price': 29.99,
        'priceString': '€29,99',
        'currencyCode': 'EUR',
        'subscriptionPeriod': 'P1Y',
      },
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('purchases_flutter');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late RevenueCatEntitlementRepository repository;
  late String sdkUser;
  late bool configured;
  late bool owned;
  late List<MethodCall> calls;
  Future<Object?> Function(MethodCall)? intercept;

  setUp(() {
    sdkUser = '';
    configured = false;
    owned = false;
    calls = [];
    intercept = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (intercept != null) {
        final result = await intercept!(call);
        if (result != null) return result;
      }
      switch (call.method) {
        case 'isConfigured':
          return configured;
        case 'setupPurchases':
          configured = true;
          sdkUser = call.arguments['appUserId'];
          return null;
        case 'logIn':
          sdkUser = call.arguments['appUserID'];
          return {'customerInfo': customer(uid: sdkUser), 'created': false};
        case 'logOut':
          sdkUser = '';
          return customer();
        case 'getCustomerInfo':
          return customer(pro: owned, uid: sdkUser);
        case 'getOfferings':
          return {
            'current': offering(),
            'all': {'default': offering()},
          };
        case 'restorePurchases':
          return customer(pro: owned, uid: sdkUser);
        case 'purchasePackage':
          throw PlatformException(code: '1');
        default:
          return null;
      }
    });
    repository = RevenueCatEntitlementRepository(apiKey: 'goog_test');
  });
  tearDown(() {
    repository.dispose();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('cancelled renewal retains access until store says entitlement is inactive', () {
    final value = entitlementFromCustomerInfo(rc.CustomerInfo.fromJson(customer(pro: true, renews: false)));
    expect(value.isPro, true);
    expect(value.willRenew, false);
    expect(value.period, BillingPeriod.yearly);
    expect(value.renewsAt, DateTime.utc(2027, 9, 27));
    expect(entitlementFromCustomerInfo(rc.CustomerInfo.fromJson(customer())).isPro, false);
    expect(
      entitlementFromCustomerInfo(rc.CustomerInfo.fromJson(customer(pro: true, verification: 'FAILED'))).isPro,
      false,
    );
  });

  test('uses store prices and configures once with Firebase identity', () async {
    repository.setUser('a');
    final offers = (await repository.offers()).valueOrNull!;
    expect(offers.single.price, '€29,99');
    expect(offers.single.packageId, r'$rc_annual');
    await repository.refresh();
    expect(calls.where((c) => c.method == 'setupPurchases').length, 1);
    expect(sdkUser, 'a');
  });

  test('purchase cancellation is distinct from an error and grants no access', () async {
    repository.setUser('a');
    final offer = (await repository.offers()).valueOrNull!.single;
    final result = await repository.purchase(offer);
    expect(result.failureOrNull?.kind, FailureKind.cancelled);
    expect((await repository.watch().first).isPro, false);
  });

  test('restore publishes verified access', () async {
    repository.setUser('a');
    await repository.refresh();
    owned = true;
    expect((await repository.restore()).valueOrNull?.isPro, true);
    expect((await repository.watch().first).isPro, true);
  });

  test('late restore result cannot grant access after account switch', () async {
    repository.setUser('a');
    await repository.refresh();
    final started = Completer<void>();
    final response = Completer<Object?>();
    intercept = (call) async {
      if (call.method == 'restorePurchases') {
        started.complete();
        return response.future;
      }
      return null;
    };
    final restore = repository.restore();
    await started.future;
    repository.setUser('b');
    expect((await repository.watch().first).isPro, false);
    response.complete(customer(pro: true));
    expect((await restore).isOk, false);
    await repository.refresh();
    expect(sdkUser, 'b');
    expect((await repository.watch().first).isPro, false);
  });

  test('successful purchase publishes Pro only after store verification', () async {
    repository.setUser('a');
    final offer = (await repository.offers()).valueOrNull!.single;
    intercept = (call) async {
      if (call.method == 'purchasePackage') {
        expect(call.arguments['packageIdentifier'], r'$rc_annual');
        return {
          'customerInfo': customer(pro: true),
          'transaction': {
            'transactionIdentifier': 'test',
            'productIdentifier': 'lastreel_pro:yearly',
            'purchaseDate': '2026-09-27T00:00:00Z',
          },
        };
      }
      return null;
    };
    expect((await repository.purchase(offer)).valueOrNull?.isPro, true);
    expect((await repository.watch().first).isPro, true);
  });

  test('pending payments remain Free and explain the pending state', () async {
    repository.setUser('a');
    final offer = (await repository.offers()).valueOrNull!.single;
    intercept = (call) async {
      if (call.method == 'purchasePackage') throw PlatformException(code: '20');
      return null;
    };
    final result = await repository.purchase(offer);
    expect(result.failureOrNull?.message, contains('pending'));
    expect((await repository.watch().first).isPro, false);
  });

  test('signed out accounts cannot buy or restore', () async {
    expect((await repository.restore()).failureOrNull?.kind, FailureKind.permission);
    expect(calls.where((c) => c.method == 'restorePurchases'), isEmpty);
  });

  test('missing offerings are a retryable error, never placeholder prices', () async {
    intercept = (call) async => call.method == 'getOfferings' ? {'current': null, 'all': <String, dynamic>{}} : null;
    repository.setUser('a');
    expect((await repository.offers()).failureOrNull?.kind, FailureKind.notFound);
  });

  group('free trials', () {
    rc.CustomerInfo info(Map<String, dynamic> json) => rc.CustomerInfo.fromJson(json);

    test('a trial is Pro in full, ending at the entitlement’s expiry', () {
      final e = entitlementFromCustomerInfo(info(customer(pro: true, periodType: 'TRIAL')));
      expect(e.isPro, isTrue);
      expect(e.isTrial, isTrue);
      expect(e.trialEndsAt, DateTime.utc(2027, 9, 27));
      expect(e.showsAds, isFalse);
    });

    test('a paid subscription is not a trial', () {
      expect(entitlementFromCustomerInfo(info(customer(pro: true))).isTrial, isFalse);
    });

    test('Pro that ended is Free, marked lapsed; never having had it is not', () {
      final lapsed = entitlementFromCustomerInfo(info(customer()));
      expect((lapsed.isPro, lapsed.lapsed), (false, true));
      final fresh = entitlementFromCustomerInfo(info(customer(everHadPro: false)));
      expect((fresh.isPro, fresh.lapsed), (false, false));
    });

    Map<String, dynamic> product({Map<String, dynamic>? freePhase, Map<String, dynamic>? intro}) => {
      'identifier': 'lastreel_pro:yearly',
      'description': 'Pro',
      'title': 'Pro',
      'price': 29.99,
      'priceString': r'$29.99',
      'currencyCode': 'USD',
      'pricePerMonthString': r'$2.50',
      'introPrice': ?intro,
      if (freePhase != null)
        'defaultOption': {
          'id': 'trial',
          'storeProductId': 'lastreel_pro:yearly',
          'productId': 'lastreel_pro',
          'pricingPhases': [freePhase],
          'tags': <String>[],
          'isBasePlan': false,
          'isPrepaid': false,
          'freePhase': freePhase,
        },
    };

    Map<String, dynamic> phase(String unit, int value) => {
      'billingPeriod': {'unit': unit, 'value': value, 'iso8601': 'P$value${unit[0]}'},
      'price': {'formatted': 'Free', 'amountMicros': 0, 'currencyCode': 'USD'},
    };

    Map<String, dynamic> intro(String unit, int units) => {
      'price': 0,
      'priceString': 'Free',
      'period': 'P$units${unit[0]}',
      'cycles': 1,
      'periodUnit': unit,
      'periodNumberOfUnits': units,
    };

    rc.StoreProduct sp(Map<String, dynamic> json) => rc.StoreProduct.fromJson(json);

    test('Play: the default option’s free phase is the trial (only eligible offers come back)', () {
      expect(freeTrialDays(sp(product(freePhase: phase('WEEK', 2))), null), 14);
      expect(freeTrialDays(sp(product(freePhase: phase('DAY', 7))), null), 7);
      expect(freeTrialDays(sp(product()), null), isNull);
    });

    test('App Store: a free introductory price, unless this account has had it', () {
      final p = sp(product(intro: intro('WEEK', 1)));
      expect(freeTrialDays(p, rc.IntroEligibilityStatus.introEligibilityStatusEligible), 7);
      expect(freeTrialDays(p, rc.IntroEligibilityStatus.introEligibilityStatusUnknown), 7);
      expect(freeTrialDays(p, rc.IntroEligibilityStatus.introEligibilityStatusIneligible), isNull);
    });

    test('offers carry the trial and the monthly figure', () {
      final offer = PlanOffer(
        period: BillingPeriod.yearly,
        price: r'$29.99',
        detail: 'Billed yearly',
        packageId: r'$rc_annual',
        trialDays: 14,
        pricePerMonth: r'$2.50',
      );
      expect(offer.ctaLabel, 'Start 14-day free trial');
      expect(offer.trialSubtitle, r'14 days free, then $2.50 a month');
      const plain = PlanOffer(period: BillingPeriod.monthly, price: r'$4.99', detail: 'Billed monthly', packageId: 'm');
      expect(plain.ctaLabel, r'Start Pro — $4.99/mo');
    });

    test('days left count a part day as a day', () {
      final e = Entitlement.pro(trialEndsAt: DateTime.utc(2026, 10, 7, 12));
      expect(e.trialDaysLeft(DateTime.utc(2026, 10, 1, 12)), 6);
      expect(e.trialDaysLeft(DateTime.utc(2026, 10, 1, 13)), 6);
      expect(e.trialDaysLeft(DateTime.utc(2026, 10, 7, 11)), 1);
      expect(e.trialDaysLeft(DateTime.utc(2026, 10, 8)), 0);
      expect(const Entitlement.free().trialDaysLeft(DateTime.utc(2026)), isNull);
    });
  });
}
