// Development-only visual preview. No Firebase, real checkout, or Pro grants.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lastreel/bootstrap.dart';
import 'package:lastreel/core/theme/app_theme.dart';
import 'package:lastreel/data/repositories/web_billing_repository.dart';
import 'package:lastreel/domain/models/app_user.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/access/controllers/web_access.dart';
import 'package:lastreel/features/plan/screens/pro_sheet.dart';
import 'package:lastreel/data/repositories/web_checkout_entitlement_repository.dart';
import 'support/fake_entitlement_repository.dart';
import 'package:lastreel/features/plan/controllers/web_billing.dart';
import 'package:lastreel/features/plan/widgets/web_pro_welcome.dart';
import 'package:lastreel/features/plan/widgets/web_subscription_card.dart';
import 'package:lastreel/features/plan/widgets/web_payment_issue.dart';

class _PreviewBilling implements WebBillingRepository {
  @override
  Future<WebBillingCatalog> catalog() async => const WebBillingCatalog(enabled: true, sandbox: true, offers: [
    PlanOffer(period: BillingPeriod.monthly, price: 'USD 4.99', detail: 'Billed every month', packageId: r'$rc_monthly', isSandbox: true),
    PlanOffer(period: BillingPeriod.yearly, price: 'USD 29.99', detail: 'Billed once a year', packageId: r'$rc_annual', isSandbox: true, pricePerMonth: 'USD 2.50', badge: 'BEST VALUE · SAVE 49%'),
  ]);
  @override
  Future<Uri> checkout(BillingPeriod period) async => Uri.parse('https://pay.rev.cat/preview');
  @override
  Future<Uri> management() async => Uri.parse('https://customer-portal.paddle.com/preview');
}

void main() {
  final previewState = Uri.base.queryParameters['state'];
  final pro = previewState == 'active' || previewState == 'settings' || previewState == 'issue';
  runApp(ProviderScope(overrides: [
    runningOnWebProvider.overrideWithValue(true),
    webBillingEnabledProvider.overrideWithValue(true),
    currentUidProvider.overrideWithValue('visual-preview'),
    authStateProvider.overrideWith((ref) => Stream.value(const AppUser(uid: 'visual-preview', email: 'preview@example.com', displayName: 'Preview'))),
    entitlementProvider.overrideWith((ref) => Stream.value(pro
      ? Entitlement.pro(period: BillingPeriod.yearly, billingStore: 'paddle', renewsAt: DateTime.utc(2027,11,3),
        billingIssue: previewState == 'issue', graceEndsAt: previewState == 'issue' ? DateTime.utc(2026,11,9) : null)
      : const Entitlement.free())),
    entitlementRepositoryProvider.overrideWithValue(WebCheckoutEntitlementRepository(
      access: FakeEntitlementRepository(), billing: _PreviewBilling(), navigate: (uri) async => true, isCurrent: () => true,
    )),
    webBillingRepositoryProvider.overrideWithValue(_PreviewBilling()),
    billingNavigationProvider.overrideWithValue((uri) async => true),
  ], child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildLastReelTheme(), home:
    previewState == 'welcome' ? WebProWelcome(onOpenProjects: () {})
    : previewState == 'settings' ? const Scaffold(body: Center(child: SizedBox(width: 580, child: WebSubscriptionCard())))
    : previewState == 'issue' ? const Scaffold(body: Center(child: SizedBox(width: 1104, child: WebPaymentIssue())))
    : const ProSheet())));
}
