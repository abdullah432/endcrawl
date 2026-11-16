import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../bootstrap.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_toast.dart';
import '../controllers/web_billing.dart';

/// D6: only server-verified billing issues can show a renewal warning.
class WebPaymentIssue extends ConsumerStatefulWidget {
  const WebPaymentIssue({super.key});
  @override
  ConsumerState<WebPaymentIssue> createState() => _WebPaymentIssueState();
}

class _WebPaymentIssueState extends ConsumerState<WebPaymentIssue> {
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
    final entitlement = ref.watch(entitlementProvider).value;
    if (entitlement == null || !entitlement.isPro || !entitlement.billingIssue) {
      return const SizedBox.shrink();
    }
    final p = context.palette;
    final t = context.type;
    final grace = entitlement.graceEndsAt;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Your renewal payment didn’t go through.',
          style: t.titleM.copyWith(fontSize: 15, color: p.amber),
        ),
        const SizedBox(height: 3),
        Text(
          grace == null
              ? 'Update your payment method to keep Pro. Your projects stay saved.'
              : 'Pro stays active during the grace period. Update your payment method by ${formatDate(grace)}. Your projects stay saved.',
          style: t.body.copyWith(fontSize: 13, height: 1.5),
        ),
      ],
    );
    final button = EcButton(
      label: 'Update payment method',
      variant: EcButtonVariant.ink,
      size: EcButtonSize.medium,
      expand: false,
      busy: _opening,
      onPressed: _opening ? null : _manage,
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: p.amberWash,
          border: Border.all(color: p.amberLine),
          borderRadius: BorderRadius.circular(18),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 700
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [copy, const SizedBox(height: 12), button],
                )
              : Row(
                  children: [
                    Icon(Icons.credit_card_rounded, size: 22, color: p.amber),
                    const SizedBox(width: 16),
                    Expanded(child: copy),
                    const SizedBox(width: 16),
                    button,
                  ],
                ),
        ),
      ),
    );
  }
}
