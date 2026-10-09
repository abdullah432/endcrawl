import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
    final manageUrl = (kIsWeb
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
          Container(
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
              EcGroupRow(
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
              if (manageUrl != null)
                EcGroupRow(
                  title: 'Change plan',
                  onTap: () => links.openUrl(manageUrl),
                ),
              if (manageUrl != null)
                EcGroupRow(
                  title: 'Billing history',
                  onTap: () => links.openUrl(manageUrl),
                ),
              if (manageUrl != null)
                EcGroupRow(
                  title: kIsWeb
                      ? 'Manage mobile subscription'
                      : 'Manage in ${AppLinks.storeName}',
                  onTap: () => links.openUrl(manageUrl),
                ),
              EcGroupRow(
                title: kIsWeb ? 'Check access' : 'Restore purchases',
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
              kIsWeb
                  ? 'Manage your subscription in its mobile store. Pro stays active until the paid period ends. When it expires, you can preview the web app; editing and exporting require Pro. Your projects stay saved.'
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
