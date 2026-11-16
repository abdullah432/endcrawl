import 'package:flutter/material.dart';
import '../../../core/config/app_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_settings.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/entitlement.dart';
import '../../library/controllers/library_controller.dart';
import '../../plan/controllers/plan_controller.dart';
import '../../plan/screens/pro_sheet.dart';
import '../../plan/controllers/web_billing.dart';
import '../../plan/widgets/web_subscription_card.dart';
import '../../access/controllers/web_access.dart' show runningOnWebProvider;

/// 7.3 — the Pro subscription, and exactly what cancelling means: nothing
/// is deleted, the free plan's projects stay editable, and ads come back.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final entitlement =
        ref.watch(entitlementProvider).value ?? const Entitlement.free();
    final count = ref.watch(projectSummariesProvider).value?.length ?? 0;
    final links = ref.read(externalLinksProvider);
    final yearly = entitlement.period == BillingPeriod.yearly;
    final paddle = entitlement.billingStore == 'paddle';
    final webBilling = ref.watch(webBillingEnabledProvider);
    final manageUrl = (AppPlatform.usesServerEntitlements
        ? entitlement.managementUrl
        : entitlement.managementUrl ?? AppLinks.manageSubscriptions);
    final renews = entitlement.renewsAt;

    return EcScaffold(
      maxContentWidth: 800,
      topBar: const EcTopBar(title: 'Subscription'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (webBilling && entitlement.isPro) const WebSubscriptionCard() else Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: p.primary,
              borderRadius: BorderRadius.circular(EcRadius.group),
              boxShadow: p.primaryShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT PLAN',
                  style: t.section.copyWith(
                    color: p.onInk.withValues(alpha: .75),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entitlement.isPro ? 'LastReel Pro' : 'Free plan',
                  style: t.displayM.copyWith(color: p.onInk),
                ),
                if (entitlement.isPro) ...[
                  const SizedBox(height: 6),
                  Text(
                    entitlement.period == null
                        ? 'Active subscription'
                        : yearly
                        ? 'Yearly subscription'
                        : 'Monthly subscription',
                    style: t.mono.copyWith(fontSize: 12, color: p.onInk),
                  ),
                  if (renews != null)
                    Text(
                      entitlement.isTrial
                          ? 'Free trial · ${entitlement.willRenew ? 'first charge' : 'ends'} ${formatDate(renews)}'
                          : '${entitlement.willRenew ? 'Renews' : 'Expires'} ${formatDate(renews)}',
                      style: t.mono.copyWith(
                        fontSize: 12,
                        color: p.onInk.withValues(alpha: .8),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          EcGroup(
            children: [
              EcGroupRow(
                title: 'Projects',
                value: entitlement.projectLimit == null
                    ? 'Unlimited · $count in use'
                    : '$count of ${entitlement.projectLimit}',
                chevron: false,
              ),
              if (!ref.watch(runningOnWebProvider)) EcGroupRow(
                title: 'Ads',
                value: entitlement.showsAds ? 'On' : 'Off',
                chevron: false,
              ),
            ],
          ),
          const SizedBox(height: 18),
          EcGroup(
            children: [
              if (!entitlement.isPro)
                EcGroupRow(
                  title: 'Get Pro',
                  onTap: () => ProSheet.show(context),
                ),
              if (manageUrl != null && !(webBilling && entitlement.isPro))
                EcGroupRow(
                  title: 'Change plan',
                  onTap: () => links.openUrl(manageUrl),
                ),
              if (manageUrl != null && !(webBilling && entitlement.isPro))
                EcGroupRow(
                  title: 'Billing history',
                  onTap: () => links.openUrl(manageUrl),
                ),
              if (manageUrl != null && !(webBilling && entitlement.isPro))
                EcGroupRow(
                  title: paddle ? 'Manage billing in Paddle' : AppPlatform.usesServerEntitlements
                      ? 'Manage mobile subscription'
                      : 'Manage in ${AppLinks.storeName}',
                  onTap: () => links.openUrl(manageUrl),
                ),
              EcGroupRow(
                title: AppPlatform.usesServerEntitlements
                    ? 'Check access'
                    : 'Restore purchases',
                onTap: () async {
                  await ref.read(planControllerProvider.notifier).restore();
                  final message = ref.read(planControllerProvider).message;
                  if (message != null && context.mounted) {
                    showEcToast(context, message);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              webBilling || paddle
                  ? 'Manage billing with the provider you subscribed through. Cancellation stops renewal; Pro stays active until the subscription ends. Your projects stay saved.'
                  : AppPlatform.usesServerEntitlements
                  ? 'Manage your subscription with its billing provider. Pro stays active until the subscription ends. The Free plan then keeps two projects editable and includes standard exports. Your projects stay saved.'
                  : 'Cancel any time in your store settings. Pro stays on until the paid period ends. After that nothing is '
                        'deleted: you keep every project, ${numberWord(Entitlement.freeProjectLimit)} can be edited, and ads come back.',
              style: t.caption.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
