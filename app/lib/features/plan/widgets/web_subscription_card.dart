import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/entitlement.dart';
import '../controllers/web_billing.dart';

/// Desktop D15. Billing details are verified; portal links are fetched on demand.
class WebSubscriptionCard extends ConsumerStatefulWidget {
  const WebSubscriptionCard({super.key});
  @override
  ConsumerState<WebSubscriptionCard> createState() =>
      _WebSubscriptionCardState();
}

class _WebSubscriptionCardState extends ConsumerState<WebSubscriptionCard> {
  bool _opening = false;
  Future<void> _manage() async {
    final uid = ref.read(currentUidProvider);
    setState(() => _opening = true);
    try {
      final url = await ref.read(webBillingRepositoryProvider).management();
      if (!mounted || ref.read(currentUidProvider) != uid) return;
      if (!await ref.read(billingNavigationProvider)(url) && mounted) {
        showEcToast(context, 'Could not open billing.');
      }
    } catch (error) {
      if (mounted && ref.read(currentUidProvider) == uid) {
        showEcToast(context, webBillingError(error));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final entitlement =
        ref.watch(entitlementProvider).value ?? const Entitlement.checking();
    final user = ref.watch(authStateProvider).value;
    final provider = switch (entitlement.billingStore) {
      'paddle' => 'Paddle',
      'play_store' => 'Google Play',
      'app_store' => 'App Store',
      _ => null,
    };
    final renewal = entitlement.renewsAt;
    final details = [
      if (user?.email != null) user!.email!,
      if (entitlement.period != null)
        entitlement.period == BillingPeriod.yearly ? 'Yearly' : 'Monthly',
      if (provider != null) 'billed by $provider',
      if (entitlement.billingIssue && entitlement.graceEndsAt != null)
        'grace period ends ${formatDate(entitlement.graceEndsAt!)}'
      else if (renewal != null && !entitlement.billingIssue)
        '${entitlement.willRenew ? 'renews' : 'ends'} ${formatDate(renewal)}',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.line),
        boxShadow: p.glassShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SUBSCRIPTION', style: t.eyebrow),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: entitlement.billingIssue ? p.amberWash : p.okWash,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 6,
                      color: entitlement.billingIssue ? p.amber : p.ok,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      entitlement.billingIssue
                          ? 'Payment due'
                          : entitlement.willRenew
                          ? 'Active'
                          : 'Ending',
                      style: t.label.copyWith(
                        color: entitlement.billingIssue ? p.amber : p.ok,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'LastReel Pro',
            style: t.displayL.copyWith(fontSize: 38, letterSpacing: 0),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(details, style: t.body),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              for (final (index, label) in [
                'Web & desktop',
                'Pro exports',
                'No ads',
              ].indexed) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: p.sheet,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 14, color: p.ink),
                        const SizedBox(width: 6),
                        Flexible(child: Text(label, style: t.bodyS)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: EcButton(
              label: 'Manage billing',
              trailing: const Icon(
                Icons.north_east_rounded,
                size: 14,
                color: Colors.white,
              ),
              variant: EcButtonVariant.ink,
              size: EcButtonSize.medium,
              expand: false,
              busy: _opening,
              onPressed: _opening ? null : _manage,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Manage billing opens ${provider ?? 'your billing provider'}’s secure portal for invoices, payment method and cancellation. '
            'If Pro ends, your projects stay saved and the Free plan keeps two projects editable with standard exports.',
            style: t.caption.copyWith(fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}
