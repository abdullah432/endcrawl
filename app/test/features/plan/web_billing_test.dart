import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/bootstrap.dart';
import 'package:lastreel/features/access/controllers/web_access.dart';
import 'package:lastreel/features/library/controllers/library_controller.dart';
import 'package:lastreel/core/theme/app_theme.dart';
import 'package:lastreel/data/repositories/web_billing_repository.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/plan/controllers/web_billing.dart';
import 'package:lastreel/features/plan/screens/pro_sheet.dart';
import 'package:lastreel/data/repositories/web_checkout_entitlement_repository.dart';
import 'package:lastreel/features/plan/widgets/web_checkout_return.dart';
import 'package:lastreel/features/settings/screens/delete_account_screen.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_auth_repository.dart';

class _Billing implements WebBillingRepository {
  final List<BillingPeriod> purchased = [];
  Completer<Uri>? pending;
  Completer<Uri>? pendingManagement;
  int managementCalls = 0;
  bool fail = false;
  @override
  Future<WebBillingCatalog> catalog() async {
    if (fail) throw Exception('Unavailable');
    return const WebBillingCatalog(enabled: true, sandbox: true, offers: [
      PlanOffer(period: BillingPeriod.monthly, price: 'USD 4.99', detail: 'Billed every month', packageId: r'$rc_monthly'),
      PlanOffer(period: BillingPeriod.yearly, price: 'USD 29.99', detail: 'Billed once a year', packageId: r'$rc_annual'),
    ]);
  }
  @override
  Future<Uri> checkout(BillingPeriod period) async {
    purchased.add(period);
    return pending?.future ?? Future.value(Uri.parse('https://pay.rev.cat/token/owner'));
  }
  @override
  Future<Uri> management() async {
    managementCalls++;
    return pendingManagement?.future ?? Future.value(Uri.parse('https://customer-portal.paddle.com/owner?token=fresh'));
  }
}

class _Uid extends Notifier<String> {
  @override
  String build() => 'owner';
  void replace(String uid) => state = uid;
}
final _uidProvider = NotifierProvider<_Uid, String>(_Uid.new);

void main() {
  test('billing URLs reject lookalikes, credentials, non-HTTPS and custom ports', () {
    for (final value in ['https://pay.rev.cat.evil.test/token', 'http://pay.rev.cat/token', 'https://user@pay.rev.cat/token', 'https://pay.rev.cat:8000/token']) {
      expect(() => verifiedBillingUrl(value, checkout: true), throwsFormatException);
    }
    expect(verifiedBillingUrl('https://pay.rev.cat/token/owner', checkout: true).host, 'pay.rev.cat');
    expect(verifiedBillingUrl('https://sandbox-customer-portal.paddle.com/customer', checkout: false).host, 'sandbox-customer-portal.paddle.com');
  });

  Future<ProviderContainer> pump(WidgetTester tester, _Billing billing, FakeEntitlementRepository plan, List<Uri> opened, {bool returned = false, bool workspace = false, Widget? screen, Size size = const Size(900, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(overrides: [
      currentUidProvider.overrideWith((ref) => ref.watch(_uidProvider)),
      projectSummariesProvider.overrideWith((ref) => Stream.value([])),
      authStateProvider.overrideWith((ref) => Stream.value(testUser)),
      entitlementProvider.overrideWith((ref) => plan.watch()),
      entitlementRepositoryProvider.overrideWith((ref) {
        final uid = ref.watch(currentUidProvider);
        return WebCheckoutEntitlementRepository(access: plan, billing: billing,
          navigate: (url) async { opened.add(url); return true; },
          isCurrent: () => ref.mounted && ref.read(currentUidProvider) == uid);
      }),
      runningOnWebProvider.overrideWithValue(true),
      webBillingEnabledProvider.overrideWithValue(true),
      webCheckoutReturnedProvider.overrideWithValue(returned),
      webBillingRepositoryProvider.overrideWithValue(billing),
      billingNavigationProvider.overrideWithValue((url) async { opened.add(url); return true; }),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(
      theme: buildLastReelTheme(),
      home: screen ?? (returned || workspace
        ? const Scaffold(body: WebCheckoutReturn(child: Center(child: Text('Workspace'))))
        : const ProSheet()),
    )));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('selected annual and monthly plans open checkout without granting Pro', (tester) async {
    final billing = _Billing();
    final plan = FakeEntitlementRepository();
    final opened = <Uri>[];
    await pump(tester, billing, plan, opened);
    expect(find.text('Yearly'), findsOneWidget);
    await tester.tap(find.text('Continue with Paddle'));
    await tester.pumpAndSettle();
    expect(billing.purchased, [BillingPeriod.yearly]);
    expect(opened, hasLength(1));
    expect(plan.entitlement.isPro, isFalse);
    await tester.ensureVisible(find.text('Monthly'));
    await tester.tap(find.text('Monthly'));
    await tester.tap(find.text('Continue with Paddle'));
    await tester.pumpAndSettle();
    expect(billing.purchased.last, BillingPeriod.monthly);
    expect(plan.entitlement.isPro, isFalse);
  });

  testWidgets('checking access only unlocks after verified entitlement changes', (tester) async {
    final plan = FakeEntitlementRepository();
    await pump(tester, _Billing(), plan, []);
    await tester.tap(find.text('Check access'));
    await tester.pumpAndSettle();
    expect(find.text('No active subscription found.'), findsOneWidget);
    plan.entitlement = const Entitlement.pro(billingStore: 'paddle');
    await tester.pumpAndSettle();
    expect(plan.entitlement.isPro, isTrue);
  });

  for (final size in [const Size(1440, 856), const Size(1100, 600)]) {
    testWidgets('desktop plan selection works without overflow at $size', (tester) async {
      final billing = _Billing();
      final plan = FakeEntitlementRepository();
      await pump(tester, billing, plan, [], size: size);
      expect(find.text('CHOOSE A PLAN'), findsOneWidget);
      expect(find.text('Full editor'), findsNWidgets(2));
      expect(find.textContaining('free trial'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Monthly'));
      await tester.ensureVisible(find.text('Continue with Paddle'));
      await tester.tap(find.text('Continue with Paddle'));
      await tester.pumpAndSettle();
      expect(billing.purchased, [BillingPeriod.monthly]);
      expect(plan.entitlement.isPro, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed catalog offers retry without fabricated plans', (tester) async {
    final billing = _Billing()..fail = true;
    await pump(tester, billing, FakeEntitlementRepository(), []);
    expect(find.text('Plans unavailable'), findsOneWidget);
    expect(find.text('Retry loading plans'), findsOneWidget);
    billing.fail = false;
    await tester.ensureVisible(find.text('Retry loading plans'));
    await tester.tap(find.text('Retry loading plans'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Paddle'), findsOneWidget);
  });

  testWidgets('late checkout response cannot navigate after account replacement', (tester) async {
    final billing = _Billing()..pending = Completer<Uri>();
    final opened = <Uri>[];
    final container = await pump(tester, billing, FakeEntitlementRepository(), opened);
    await tester.tap(find.text('Continue with Paddle'));
    await tester.pump();
    container.read(_uidProvider.notifier).replace('next-owner');
    await tester.pump();
    billing.pending!.complete(Uri.parse('https://pay.rev.cat/token/owner'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });

  testWidgets('return redirect stays Free until verification succeeds', (tester) async {
    final plan = FakeEntitlementRepository();
    await pump(tester, _Billing(), plan, [], returned: true);
    expect(plan.entitlement.isPro, isFalse);
    expect(find.textContaining('not confirmed yet'), findsOneWidget);
    plan.entitlement = const Entitlement.pro();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Pro is active. Your workspace is ready.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('verified desktop Pro skips the plan picker and prevents a second purchase', (tester) async {
    final billing = _Billing();
    final plan = FakeEntitlementRepository()..entitlement = const Entitlement.pro(billingStore: 'play_store');
    await pump(tester, billing, plan, [], size: const Size(1440, 856));
    expect(find.textContaining('You already have Pro', findRichText: true), findsOneWidget);
    expect(find.text('Continue with Paddle'), findsNothing);
    expect(billing.purchased, isEmpty);
  });

  testWidgets('a verified billing issue shows a repair action without blocking the workspace', (tester) async {
    final billing = _Billing();
    final plan = FakeEntitlementRepository()..entitlement = Entitlement.pro(
      billingStore: 'paddle', billingIssue: true, graceEndsAt: DateTime.utc(2026,11,9));
    final opened = <Uri>[];
    await pump(tester, billing, plan, opened, workspace: true, size: const Size(1440,856));
    expect(find.text('Your renewal payment didn’t go through.'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    await tester.tap(find.text('Update payment method'));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'customer-portal.paddle.com');
    plan.entitlement = const Entitlement.pro(billingStore: 'paddle');
    await tester.pumpAndSettle();
    expect(find.text('Your renewal payment didn’t go through.'), findsNothing);
  });

  testWidgets('management fetches a fresh provider URL for verified Pro', (tester) async {
    final billing = _Billing();
    final plan = FakeEntitlementRepository()..entitlement = const Entitlement.pro(billingStore: 'paddle');
    final opened = <Uri>[];
    await pump(tester, billing, plan, opened);
    await tester.tap(find.text('Manage billing'));
    await tester.pumpAndSettle();
    expect(billing.managementCalls, 1);
    expect(opened.single.host, 'customer-portal.paddle.com');
  });

  testWidgets('a portal response from the previous account cannot navigate', (tester) async {
    final billing = _Billing()..pendingManagement = Completer<Uri>();
    final plan = FakeEntitlementRepository()..entitlement = const Entitlement.pro(billingStore: 'paddle');
    final opened = <Uri>[];
    final container = await pump(tester, billing, plan, opened);
    await tester.tap(find.text('Manage billing'));
    await tester.pump();
    container.read(_uidProvider.notifier).replace('next-owner');
    await tester.pump();
    billing.pendingManagement!.complete(Uri.parse('https://customer-portal.paddle.com/owner?token=fresh'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
  });

  testWidgets('account deletion directs web subscribers to their provider without deleting', (tester) async {
    final billing = _Billing();
    final plan = FakeEntitlementRepository()..entitlement = const Entitlement.pro(billingStore: 'paddle');
    final opened = <Uri>[];
    await pump(tester, billing, plan, opened, screen: const DeleteAccountScreen());
    expect(find.text('Deleting doesn’t cancel a subscription.'), findsOneWidget);
    await tester.tap(find.text('Manage billing ›'));
    await tester.pumpAndSettle();
    expect(opened.single.host, 'customer-portal.paddle.com');
    expect(find.text('Manage billing ›'), findsOneWidget);
  });
}
