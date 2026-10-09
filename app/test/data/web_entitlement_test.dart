import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/data/repositories/web_entitlement_repository.dart';
import 'package:lastreel/domain/models/entitlement.dart';

void main() {
  final now = DateTime.utc(2026, 10, 9);
  test('verified ledger maps active trial and rejects expired access', () {
    final data = <String, dynamic>{
      'schemaVersion': 1,
      'plan': 'pro',
      'period': 'monthly',
      'willRenew': true,
      'expiresAtMs': now.add(const Duration(days: 7)).millisecondsSinceEpoch,
      'trialEndsAtMs': now.add(const Duration(days: 7)).millisecondsSinceEpoch,
    };
    final active = entitlementFromLedger(data, now);
    expect(active.isTrial, isTrue);
    expect(active.period, BillingPeriod.monthly);
    final expired = entitlementFromLedger(
      data,
      now.add(const Duration(days: 8)),
    );
    expect(expired.isPro, isFalse);
    expect(expired.lapsed, isTrue);
    expect(
      entitlementFromLedger({...data, 'schemaVersion': 2}, now).isPro,
      isFalse,
    );
  });
}
