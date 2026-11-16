import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../domain/models/entitlement.dart';
import '../../settings/models/legal_document.dart';
import '../../settings/screens/legal_document_screen.dart';
import '../controllers/plan_controller.dart';

/// Desktop D2: the shared paywall, with server-priced plans and hosted checkout.
/// Smaller web windows retain the tablet/compact compositions in ProSheet.
class DesktopPaywall extends ConsumerWidget {
  final PlanSource source;
  const DesktopPaywall({super.key, required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(planControllerProvider);
    final controller = ref.read(planControllerProvider.notifier);
    final t = context.type;
    final p = context.palette;
    final offers = [...state.offers]
      ..sort(
        (a, b) => (a.period == BillingPeriod.yearly ? 0 : 1).compareTo(
          b.period == BillingPeriod.yearly ? 0 : 1,
        ),
      );
    final selected = state.selected;
    final sandbox = offers.any((offer) => offer.isSandbox);
    return Scaffold(
      backgroundColor: p.sheet,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: SizedBox(
              height: math.max(
                state.message == null ? 820 : 940,
                constraints.maxHeight,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: constraints.maxWidth * 5 / 12,
                    child: const _CreditsHero(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        constraints.maxWidth < 1300 ? 36 : 64,
                        40,
                        constraints.maxWidth < 1300 ? 36 : 64,
                        30,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'CHOOSE A PLAN',
                            style: t.eyebrow.copyWith(
                              fontSize: 10.5,
                              letterSpacing: 1.47,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Semantics(
                            header: true,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'Choose Pro, '),
                                  TextSpan(
                                    text: 'your way.',
                                    style: GoogleFonts.instrumentSerif(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                              style: t.displayL.copyWith(
                                fontSize: 40,
                                height: 1,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (state.loading)
                            const SizedBox(
                              height: 166,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (offers.isEmpty)
                            SizedBox(
                              height: 166,
                              child: Center(
                                child: EcButton.text(
                                  label: 'Retry loading plans',
                                  onPressed: controller.loadOffers,
                                  expand: false,
                                ),
                              ),
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final (i, offer) in offers.indexed) ...[
                                  if (i > 0) const SizedBox(width: 14),
                                  Expanded(
                                    child: _PlanCard(
                                      offer: offer,
                                      selected: offer == selected,
                                      onTap: state.busy
                                          ? null
                                          : () => controller.select(offer),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          const SizedBox(height: 20),
                          const _Comparison(),
                          const Spacer(),
                          if (state.message != null) ...[
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                state.message!,
                                style: t.bodyS,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (sandbox) ...[
                            Text(
                              'SANDBOX · TEST PAYMENTS ONLY',
                              textAlign: TextAlign.center,
                              style: t.eyebrow.copyWith(color: p.muted),
                            ),
                            const SizedBox(height: 10),
                          ],
                          EcButton(
                            label: state.loading
                                ? 'Loading plans…'
                                : selected == null
                                ? 'Plans unavailable'
                                : 'Continue with Paddle',
                            height: 58,
                            busy: state.purchasing,
                            onPressed:
                                state.busy || state.loading || selected == null
                                ? null
                                : () async {
                                    final ok = await controller.purchase(
                                      source: source,
                                    );
                                    if (ok && context.mounted) {
                                      Navigator.of(context).maybePop();
                                    }
                                  },
                          ),
                          const SizedBox(height: 10),
                          Text(
                            selected == null
                                ? 'Choose a plan to continue to secure checkout.'
                                : '${selected.price}${selected.period == BillingPeriod.yearly ? ' a year' : ' a month'}, billed ${selected.period == BillingPeriod.yearly ? 'yearly' : 'monthly'}. '
                                      'Renews automatically. Cancel anytime; Pro stays active until your subscription ends.',
                            textAlign: TextAlign.center,
                            style: t.bodyS.copyWith(
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 22,
                            runSpacing: 8,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    size: 12,
                                    color: p.muted,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Secure checkout by Paddle',
                                    style: t.caption.copyWith(fontSize: 12),
                                  ),
                                ],
                              ),
                              Text(
                                'Taxes shown at checkout',
                                style: t.caption.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              EcButton(
                                label: 'Check access',
                                variant: EcButtonVariant.text,
                                size: EcButtonSize.small,
                                busy: state.restoring,
                                onPressed: state.busy
                                    ? null
                                    : controller.restore,
                              ),
                              EcButton(
                                label: 'Stay on Free',
                                variant: EcButtonVariant.plain,
                                size: EcButtonSize.small,
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                              EcButton(
                                label: 'Terms',
                                variant: EcButtonVariant.plain,
                                size: EcButtonSize.small,
                                onPressed: () => LegalDocumentScreen.open(
                                  context,
                                  termsOfService,
                                ),
                              ),
                              EcButton(
                                label: 'Refunds',
                                variant: EcButtonVariant.plain,
                                size: EcButtonSize.small,
                                onPressed: () => LegalDocumentScreen.open(
                                  context,
                                  refundPolicy,
                                ),
                              ),
                              EcButton(
                                label: 'Privacy',
                                variant: EcButtonVariant.plain,
                                size: EcButtonSize.small,
                                onPressed: () => ref
                                    .read(externalLinksProvider)
                                    .openUrl(AppLinks.privacyPolicy),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CreditsHero extends StatelessWidget {
  final bool existing;
  const _CreditsHero({this.existing = false});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: .85,
                  colors: [Color(0x6B0C8CE9), Color(0x000C8CE9)],
                  stops: [0, .7],
                ),
              ),
            ),
          ),
          if (!existing)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomRight,
                    radius: .75,
                    colors: [Color(0x576A5AF5), Color(0x006A5AF5)],
                    stops: [0, .7],
                  ),
                ),
              ),
            ),
          if (!existing && MediaQuery.sizeOf(context).height >= 760)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              height: 300,
              child: ExcludeSemantics(
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0, .25, .75, 1],
                  ).createShader(bounds),
                  child: Column(
                    children: [
                      const SizedBox(height: 18),
                      _credit('DIRECTOR OF PHOTOGRAPHY', role: true),
                      const SizedBox(height: 10),
                      _credit('YUSUF KARADENIZ'),
                      const SizedBox(height: 26),
                      _credit('ORIGINAL MUSIC', role: true),
                      const SizedBox(height: 10),
                      _credit('HANA BEXLEY'),
                      const SizedBox(height: 28),
                      _credit('CAST', role: true),
                      const SizedBox(height: 12),
                      _cast('RENNY', 'SOFIA ALVAREZ'),
                      _cast('MARCUS', 'IDRIS OYELARAN'),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 52),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LASTREEL',
                      style: GoogleFonts.archivoNarrow(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4.42,
                        color: Colors.white,
                      ),
                    ),
                    if (!existing)
                      IconButton.filledTonal(
                        tooltip: 'Close and stay on Free',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: .14),
                          fixedSize: const Size(44, 44),
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                if (!existing)
                  Text(
                    'LASTREEL PRO',
                    style: t.mono.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.76,
                      color: Colors.white.withValues(alpha: .6),
                    ),
                  ),
                if (!existing) const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Unlimited projects. '),
                      TextSpan(
                        text: 'Pro formats.',
                        style: GoogleFonts.instrumentSerif(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const TextSpan(text: ' No ads.'),
                    ],
                  ),
                  style: t.displayXL.copyWith(
                    fontSize: 62,
                    height: .98,
                    color: Colors.white,
                    letterSpacing: 0,
                  ),
                ),
                if (!existing) const SizedBox(height: 16),
                if (!existing)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Text(
                      'One subscription for the desk editor here and the app on your phone and tablet, on the same account.',
                      style: t.body.copyWith(
                        fontSize: 15,
                        height: 1.55,
                        color: Colors.white.withValues(alpha: .72),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _credit(String text, {bool role = false}) => Text(
    text,
    style: GoogleFonts.archivoNarrow(
      fontSize: role ? 10 : 20,
      fontWeight: role ? FontWeight.w400 : FontWeight.w600,
      letterSpacing: role ? 3.4 : 2.8,
      color: Colors.white.withValues(alpha: role ? .5 : 1),
      height: 1.2,
    ),
  );

  Widget _cast(String role, String name) => SizedBox(
    width: 400,
    child: Row(
      children: [
        Expanded(
          child: Text(
            role,
            textAlign: TextAlign.right,
            style: GoogleFonts.archivoNarrow(
              fontSize: 14,
              height: 2,
              letterSpacing: 1.68,
              color: Colors.white.withValues(alpha: .6),
            ),
          ),
        ),
        const SizedBox(width: 26),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.archivoNarrow(
              fontSize: 14,
              height: 2,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.68,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

/// D5: an account with verified Pro sees its existing subscription, never a second purchase.
class DesktopProActive extends ConsumerWidget {
  const DesktopProActive({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final entitlement = ref.watch(entitlementProvider).value;
    final provider = switch (entitlement?.billingStore) {
      'paddle' => 'Paddle',
      'play_store' => 'Google Play',
      'app_store' => 'the App Store',
      _ => 'your existing subscription',
    };
    return Scaffold(
      backgroundColor: p.sheet,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: MediaQuery.sizeOf(context).width * 5 / 12,
            child: const _CreditsHero(existing: true),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 64,
                ),
                child: Container(
                  width: 560,
                  padding: const EdgeInsets.symmetric(
                    vertical: 34,
                    horizontal: 36,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: p.line),
                    boxShadow: p.glassShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: p.okWash,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'Pro is active',
                          style: t.label.copyWith(color: p.ok),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'You already have Pro '),
                            TextSpan(
                              text: 'through $provider.',
                              style: GoogleFonts.instrumentSerif(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        style: t.displayL.copyWith(
                          fontSize: 42,
                          height: 1.02,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Your subscription includes the web and the apps on the same account. Your Pro features are ready to use.',
                        style: t.body.copyWith(fontSize: 14.5, height: 1.55),
                      ),
                      const SizedBox(height: 18),
                      EcButton(
                        label: 'Open my projects',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Manage your existing subscription in Settings → Subscription.',
                        style: t.caption.copyWith(fontSize: 12.5, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanOffer offer;
  final bool selected;
  final VoidCallback? onTap;
  const _PlanCard({
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final yearly = offer.period == BillingPeriod.yearly;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label:
          '${yearly ? 'Yearly' : 'Monthly'} plan, ${offer.price}${offer.perPeriod}',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 166,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? p.accentSolid : p.line2,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: p.accentSolid.withValues(alpha: .1),
                        spreadRadius: 5,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 22,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            yearly ? 'Yearly' : 'Monthly',
                            style: t.titleM.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? p.accentSolid : p.line2,
                                width: selected ? 6 : 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              offer.price,
                              maxLines: 1,
                              style: t.displayL.copyWith(
                                fontSize: 38,
                                height: 1,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            yearly ? '/ year' : '/ month',
                            style: t.caption.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        yearly && offer.pricePerMonth != null
                            ? '${offer.pricePerMonth} / month · billed yearly'
                            : yearly
                            ? 'Billed yearly · cancel anytime'
                            : 'Billed monthly · cancel anytime',
                        style: t.bodyS.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (offer.badge != null)
            Positioned(
              right: 16,
              top: -12,
              child: Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: p.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  offer.badge!,
                  style: t.mono.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison();
  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    Widget row(String label, String free, String pro, {bool header = false}) =>
        Container(
          decoration: BoxDecoration(
            border: header ? null : Border(top: BorderSide(color: p.line)),
          ),
          padding: EdgeInsets.only(top: header ? 0 : 9, bottom: header ? 8 : 9),
          child: Row(
            children: [
              for (final (i, value) in [label, free, pro].indexed)
                Expanded(
                  flex: i == 0 ? 14 : 10,
                  child: Text(
                    value,
                    style: header
                        ? t.mono.copyWith(
                            fontSize: 10,
                            letterSpacing: 1.4,
                            color: i == 2 ? p.accent : p.muted,
                          )
                        : t.body.copyWith(
                            fontSize: 13.5,
                            height: 1.2,
                            color: i == 0 ? p.muted : p.ink,
                            fontWeight: i == 2
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                  ),
                ),
            ],
          ),
        );
    return Column(
      children: [
        row('WHAT YOU GET', 'FREE', 'PRO', header: true),
        row('Desk editor on the web', 'Full editor', 'Full editor'),
        row('Projects', '${Entitlement.freeProjectLimit}', 'Unlimited'),
        row('Web formats', 'H.264 MP4', '+ PNG alpha'),
        row('Resolution', 'Up to 1080p', 'Up to 4K'),
        row('Ads in the apps', 'Shown', 'None'),
      ],
    );
  }
}
