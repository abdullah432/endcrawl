import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/domain/models/entitlement.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';

void main() {
  final ends = DateTime.utc(2026, 10, 7);

  testWidgets('a trial that turns into paid Pro logs trial_converted', (tester) async {
    final plan = FakeEntitlementRepository(Entitlement.pro(period: BillingPeriod.yearly, trialEndsAt: ends));
    final app = AppHarness(plan: plan);
    await app.pump(tester);

    plan.entitlement = const Entitlement.pro(period: BillingPeriod.yearly);
    await tester.pumpAndSettle();

    expect(app.analytics.names, contains('trial_converted'));
    expect(app.analytics.events.firstWhere((e) => e.$1 == 'trial_converted').$2, {'plan': 'yearly'});
  });

  testWidgets('a trial that stops renewing logs trial_cancelled', (tester) async {
    final plan = FakeEntitlementRepository(Entitlement.pro(period: BillingPeriod.monthly, trialEndsAt: ends));
    final app = AppHarness(plan: plan);
    await app.pump(tester);

    plan.entitlement = Entitlement.pro(period: BillingPeriod.monthly, trialEndsAt: ends, willRenew: false);
    await tester.pumpAndSettle();

    expect(app.analytics.names, contains('trial_cancelled'));
    expect(app.analytics.names, isNot(contains('trial_converted')));
  });

  testWidgets('a paid plan changing logs nothing about trials', (tester) async {
    final plan = FakeEntitlementRepository(const Entitlement.pro(period: BillingPeriod.monthly));
    final app = AppHarness(plan: plan);
    await app.pump(tester);

    plan.entitlement = const Entitlement.pro(period: BillingPeriod.monthly, willRenew: false);
    await tester.pumpAndSettle();

    expect(app.analytics.names.where((n) => n.startsWith('trial_')), isEmpty);
  });
}
