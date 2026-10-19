import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/mobile_subscription_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_choice_card.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/entitlement.dart';
import '../../settings/screens/legal_document_screen.dart';
import '../../settings/models/legal_document.dart';
import '../controllers/plan_controller.dart';
import '../controllers/release_policy.dart';
import '../../home/tablet_layout.dart';

/// 6.5 — LastReel Pro.
///
/// Three reasons in one headline: more projects, pro formats, no ads. The
/// table makes plain that editing is identical on both plans; only the
/// project cap and the export formats differ.
class ProSheet extends ConsumerWidget {
  /// Where the user came from, for the trial funnel's analytics.
  final PlanSource source;

  const ProSheet({super.key, this.source = PlanSource.paywall});

  static Future<void> show(
    BuildContext context, {
    PlanSource source = PlanSource.paywall,
  }) async {
    if (ProviderScope.containerOf(context, listen: false).read(iosFreeLaunchProvider)) return;
    if (kIsWeb) {
      await MobileSubscriptionCard.show(context);
    } else if (context.isTablet) {
      // T6.3 / P6.3: the whole screen, the black panel beside or above.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => ProSheet(source: source)),
      );
    } else {
      await showEcSheet<void>(context, builder: (_) => ProSheet(source: source));
    }
  }

  static const _comparison = <(String, String, String)>[
    ('Projects', '${Entitlement.freeProjectLimit}', 'Unlimited'),
    ('Ads', 'Shown', 'None'),
    ('Blocks, timing, look', 'Everything', 'Everything'),
    ('Codecs', 'H.264, HEVC', '+ ProRes, PNG'),
    ('Resolution', 'Up to 1080p', 'Up to 4K'),
    ('Pro render on Free', '1 per rewarded ad', 'Every render'),
    ('Watermark', 'None', 'None'),
    ('LastReel on the web', 'Preview only', 'Full editor'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(planControllerProvider);
    final controller = ref.read(planControllerProvider.notifier);
    final p = context.palette;
    final t = context.type;
    final selected = state.selected;
    final trialEnds = selected != null && selected.hasTrial
        ? ref.read(clockProvider)().add(Duration(days: selected.trialDays!))
        : null;
    if (context.isTablet) return _tablet(context, ref, trialEnds);

    return EcSheet(
      maxHeightFraction: 0.94,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: EcCircleButton.glass(
            icon: Icons.close_rounded,
            size: 34,
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.message != null) ...[
              EcNotice(
                tone: EcTone.neutral,
                title: state.message!,
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: 10),
            ],
            EcButton(
              label: state.loading
                  ? 'Loading plans…'
                  : selected == null
                  ? 'Plans unavailable'
                  : selected.ctaLabel,
              busy: state.purchasing,
              onPressed: state.busy || state.loading || selected == null
                  ? null
                  : () async {
                      final ok = await controller.purchase(source: source);
                      if (ok && context.mounted) Navigator.of(context).pop();
                    },
            ),
            // The first charge date, spelled out (Play and App Store both
            // ask for it next to a trial).
            if (selected != null && trialEnds != null) ...[
              const SizedBox(height: 8),
              Text(
                'Free until ${formatDayMonth(trialEnds)}, then ${selected.price}${selected.perPeriod}. '
                'Cancel before then and you pay nothing.',
                textAlign: TextAlign.center,
                style: t.caption,
              ),
            ],
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                EcButton(
                  label: 'Restore purchase',
                  variant: EcButtonVariant.plain,
                  size: EcButtonSize.small,
                  busy: state.restoring,
                  onPressed: state.busy ? null : controller.restore,
                ),
                EcButton(
                  label: 'Stay on Free',
                  variant: EcButtonVariant.text,
                  size: EcButtonSize.small,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EcEyebrow('LastReel Pro', color: p.accent),
                const SizedBox(height: 10),
                EcHeadline(
                  'Unlimited projects.\n',
                  emphasis: 'Pro formats. No ads.',
                  style: t.displayL.copyWith(fontSize: 44),
                ),
                const SizedBox(height: 10),
                Text(
                  'Free has every block, timing and look tool, with H.264 and HEVC up to 1080p. Pro lifts the '
                  '${numberWord(Entitlement.freeProjectLimit)}-project cap, '
                  'unlocks ProRes, PNG and 4K on every render, and removes ads.',
                  style: t.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!state.loading && state.offers.isEmpty)
            EcButton(
              label: 'Retry loading plans',
              variant: EcButtonVariant.text,
              onPressed: controller.loadOffers,
            ),
          for (final offer in state.offers) ...[
            _OfferTile(
              offer: offer,
              selected: offer == selected,
              onTap: () => controller.select(offer),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          _ComparisonTable(rows: _comparison),
          const SizedBox(height: 16),
          Text(
            'Payment is charged to your store account. Subscriptions renew automatically at the displayed price for the selected period unless cancelled in your store settings. Cancel anytime; access continues until the paid period ends.',
            style: t.caption,
          ),
          Wrap(
            children: [
              EcButton(
                label: 'Terms of service',
                variant: EcButtonVariant.text,
                size: EcButtonSize.small,
                onPressed: () =>
                    LegalDocumentScreen.open(context, termsOfService),
              ),
              EcButton(
                label: 'Privacy policy',
                variant: EcButtonVariant.text,
                size: EcButtonSize.small,
                onPressed: () => ref
                    .read(externalLinksProvider)
                    .openUrl(AppLinks.privacyPolicy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on ProSheet {
  /// T6.3 / P6.3 — the black panel says what Pro is; the other side
  /// compares the plans, then the plans, the button and the way back.
  Widget _tablet(BuildContext context, WidgetRef ref, DateTime? trialEnds) {
    final state = ref.watch(planControllerProvider);
    final controller = ref.read(planControllerProvider.notifier);
    final p = context.palette;
    final t = context.type;
    final selected = state.selected;
    final portrait = context.tabletLayout == TabletLayout.portrait;
    final white = Colors.white;

    final hero = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-1, -1),
          radius: 1.2,
          colors: [Color(0x6B0C8CE9), Color(0x000C8CE9)],
          stops: [0, .5],
        ),
      ),
      child: SafeArea(
        right: portrait,
        bottom: !portrait,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(44, 40, 44, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Material(
                color: white.withValues(alpha: .14),
                shape: CircleBorder(side: BorderSide(color: white.withValues(alpha: .2))),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.close_rounded, size: 18, color: white),
                ),
              ),
              const Spacer(),
              Text('LASTREEL PRO', style: t.mono.copyWith(fontSize: 10.5, letterSpacing: 1.6, color: white.withValues(alpha: .6))),
              const SizedBox(height: 14),
              Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Unlimited projects. '),
                      TextSpan(text: 'Pro formats', style: TextStyle(fontStyle: FontStyle.italic, color: white)),
                      const TextSpan(text: '. No ads.'),
                    ],
                  ),
                  style: t.displayXL.copyWith(fontSize: portrait ? 54 : 52, height: 1.05, color: white),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Pro also unlocks LastReel on the web, on the same account.',
                style: t.body.copyWith(fontSize: 14, color: white.withValues(alpha: .75)),
              ),
            ],
          ),
        ),
      ),
    );

    final details = SafeArea(
      left: portrait,
      top: !portrait,
      child: Padding(
        padding: portrait ? const EdgeInsets.fromLTRB(44, 32, 44, 28) : const EdgeInsets.fromLTRB(44, 40, 44, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!portrait) ...[
                      Text(
                        'Free has every block, timing and look tool. Pro lifts the '
                        '${numberWord(Entitlement.freeProjectLimit)}-project cap, unlocks ProRes, PNG and 4K on every '
                        'render, and removes ads.',
                        style: t.body.copyWith(fontSize: 15, height: 1.5, color: p.ink2),
                      ),
                      const SizedBox(height: 18),
                    ],
                    _ComparisonTable(rows: ProSheet._comparison, open: true),
                    const SizedBox(height: 22),
                    if (!state.loading && state.offers.isEmpty)
                      EcButton(label: 'Retry loading plans', variant: EcButtonVariant.text, onPressed: controller.loadOffers),
                    Row(
                      children: [
                        for (final (i, offer) in state.offers.indexed) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: _OfferTile(offer: offer, selected: offer == selected, onTap: () => controller.select(offer)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (state.message != null) ...[
              EcNotice(tone: EcTone.neutral, title: state.message!, icon: Icons.info_outline_rounded),
              const SizedBox(height: 10),
            ],
            EcButton(
              label: state.loading
                  ? 'Loading plans…'
                  : selected == null
                  ? 'Plans unavailable'
                  : selected.ctaLabel,
              height: 56,
              busy: state.purchasing,
              onPressed: state.busy || state.loading || selected == null
                  ? null
                  : () async {
                      final ok = await controller.purchase(source: source);
                      if (ok && context.mounted) Navigator.of(context).pop();
                    },
            ),
            const SizedBox(height: 8),
            Text(
              selected != null && trialEnds != null
                  ? 'Free until ${formatDayMonth(trialEnds)}, then ${selected.price}${selected.perPeriod}. '
                        'Cancel before then and you pay nothing. Billing and cancellation happen in ${AppLinks.storeName}.'
                  : 'Billing and cancellation happen in ${AppLinks.storeName}.',
              textAlign: TextAlign.center,
              style: t.caption,
            ),
            const SizedBox(height: 4),
            // The auto-renewal terms every purchase screen must carry.
            Text(
              'Payment is charged to your store account. Subscriptions renew automatically at the displayed price for the selected period unless cancelled in your store settings. Cancel anytime; access continues until the paid period ends.',
              textAlign: TextAlign.center,
              style: t.caption,
            ),
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                EcButton(
                  label: 'Restore purchase',
                  variant: EcButtonVariant.text,
                  size: EcButtonSize.small,
                  busy: state.restoring,
                  onPressed: state.busy ? null : controller.restore,
                ),
                EcButton(
                  label: 'Stay on Free',
                  variant: EcButtonVariant.plain,
                  size: EcButtonSize.small,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                EcButton(
                  label: 'Terms',
                  variant: EcButtonVariant.plain,
                  size: EcButtonSize.small,
                  onPressed: () => LegalDocumentScreen.open(context, termsOfService),
                ),
                EcButton(
                  label: 'Privacy',
                  variant: EcButtonVariant.plain,
                  size: EcButtonSize.small,
                  onPressed: () => ref.read(externalLinksProvider).openUrl(AppLinks.privacyPolicy),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final panel = ColoredBox(color: Colors.black, child: hero);
    return Scaffold(
      backgroundColor: p.sheet,
      body: portrait
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 400 + MediaQuery.paddingOf(context).top, child: panel),
                Expanded(child: details),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 440, child: panel),
                Expanded(child: details),
              ],
            ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  final PlanOffer offer;
  final bool selected;
  final VoidCallback onTap;

  const _OfferTile({
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return EcChoiceCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: selected ? p.primary : null,
              border: selected ? null : Border.all(color: p.line2, width: 1.5),
            ),
            child: selected
                ? Icon(Icons.check_rounded, size: 14, color: p.onInk)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      offer.period == BillingPeriod.yearly
                          ? 'Yearly'
                          : 'Monthly',
                      style: t.titleS,
                    ),
                    if (offer.badge != null) ...[
                      const SizedBox(width: 6),
                      EcGradientPill(offer.badge!),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(offer.trialSubtitle, style: t.caption),
              ],
            ),
          ),
          Text(
            offer.price,
            style: t.monoM.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final List<(String, String, String)> rows;

  /// T6.3: straight on the page, rules between rows, no card.
  final bool open;
  const _ComparisonTable({required this.rows, this.open = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    Widget row(String a, String b, String c, {bool header = false}) {
      final base = header
          ? t.pill.copyWith(color: p.muted)
          : t.bodyS.copyWith(fontSize: open ? 14 : 12);
      return Container(
        color: header && !open ? p.tint : null,
        padding: EdgeInsets.symmetric(
          horizontal: open ? 0 : 14,
          vertical: header ? 10 : (open ? 11 : 11),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                header ? a.toUpperCase() : a,
                style: header ? base : base.copyWith(color: p.ink2),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                header ? b.toUpperCase() : b,
                style: base.copyWith(color: p.muted),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                header ? c.toUpperCase() : c,
                style: header
                    ? base.copyWith(color: p.accent)
                    : base.copyWith(color: p.ink, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (open) {
      return Column(
        children: [
          row('Plan', 'Free', 'Pro', header: true),
          for (final (a, b, c) in rows) ...[
            Divider(height: 1, color: p.line),
            row(a, b, c),
          ],
        ],
      );
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(EcRadius.card),
      ),
      child: Column(
        children: [
          row('Plan', 'Free', 'Pro', header: true),
          for (final (a, b, c) in rows) ...[
            Divider(height: 1, color: p.line),
            row(a, b, c),
          ],
        ],
      ),
    );
  }
}
