import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_settings.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/entitlement.dart';
import '../../library/controllers/library_controller.dart';
import '../../plan/controllers/plan_controller.dart';
import '../../plan/screens/pro_sheet.dart';

/// 7.3 — the Pro subscription, and exactly what cancelling means: nothing
/// is deleted, three projects stay editable, and ads come back.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final entitlement = ref.watch(entitlementProvider).value ?? const Entitlement.free();
    final count = ref.watch(projectSummariesProvider).value?.length ?? 0;
    final links = ref.read(externalLinksProvider);
    final yearly = entitlement.period == BillingPeriod.yearly;
    final offer = yearly ? PlanOffer.yearly : PlanOffer.monthly;
    final renews = entitlement.renewsAt;

    return EcScaffold(
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
                Text('CURRENT PLAN', style: t.section.copyWith(color: p.onInk.withValues(alpha: .75))),
                const SizedBox(height: 8),
                Text(entitlement.isPro ? 'LastReel Pro' : 'Free plan', style: t.displayM.copyWith(color: p.onInk)),
                if (entitlement.isPro) ...[
                  const SizedBox(height: 6),
                  Text('${yearly ? 'Yearly' : 'Monthly'} · ${offer.price}', style: t.mono.copyWith(fontSize: 12, color: p.onInk)),
                  if (renews != null)
                    Text('Renews ${_date(renews)}', style: t.mono.copyWith(fontSize: 12, color: p.onInk.withValues(alpha: .8))),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          EcGroup(children: [
            EcGroupRow(
              title: 'Projects',
              value: entitlement.projectLimit == null ? 'Unlimited · $count in use' : '$count of ${entitlement.projectLimit}',
              chevron: false,
            ),
            EcGroupRow(title: 'Ads', value: entitlement.showsAds ? 'On' : 'Off', chevron: false),
          ]),
          const SizedBox(height: 18),
          EcGroup(children: [
            EcGroupRow(title: 'Change plan', value: yearly ? 'Yearly' : 'Monthly', onTap: () => ProSheet.show(context)),
            EcGroupRow(title: 'Billing history', onTap: () => links.openUrl(AppLinks.manageSubscriptions)),
            EcGroupRow(title: 'Manage in App Store', onTap: () => links.openUrl(AppLinks.manageSubscriptions)),
            EcGroupRow(
              title: 'Restore purchases',
              onTap: () async {
                await ref.read(planControllerProvider.notifier).restore();
                final message = ref.read(planControllerProvider).message;
                if (message != null && context.mounted) showEcToast(context, message);
              },
            ),
          ]),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'Cancel any time in App Store settings. Pro stays on until the renewal date. After that nothing is '
              'deleted: you keep every project, three can be edited, and ads come back.',
              style: t.caption.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
}
