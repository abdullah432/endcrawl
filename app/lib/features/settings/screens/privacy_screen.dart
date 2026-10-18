import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/result.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_settings.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/user_profile.dart';
import '../../ads/ads_providers.dart';
import '../controllers/settings_controller.dart';
import 'delete_account_screen.dart';

/// 7.4 — plain language about what is kept, three switches with honest
/// defaults, and a way out.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final prefs = (ref.watch(userProfileProvider).value ?? const UserProfile())
        .preferences;
    final settings = ref.read(settingsControllerProvider);

    void update(Preferences Function(Preferences) change) async {
      final result = await settings.updatePreferences(change);
      if (result case Err(:final failure) when context.mounted) {
        showEcToast(context, failure.message);
      }
    }

    return EcScaffold(
      maxContentWidth: 800,
      topBar: const EcTopBar(title: 'Privacy & data'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
            child: EcHeadline(
              'What we keep, and ',
              emphasis: 'what you control.',
              style: t.displayM,
            ),
          ),
          const EcGroup(
            label: 'Stored with your account',
            children: [
              EcGroupRow(
                title: 'Account',
                subtitle: 'Name, email and sign-in method',
                chevron: false,
              ),
              EcGroupRow(
                title: 'Projects & renders',
                subtitle: 'Synced so they survive a new phone',
                chevron: false,
              ),
              EcGroupRow(
                title: 'Purchases',
                subtitle:
                    'Your store handles payment; RevenueCat manages plan status.',
                chevron: false,
              ),
              EcGroupRow(
                title: 'Session insights',
                subtitle:
                    'Microsoft Clarity records how screens are used. Emails and passwords are hidden.',
                chevron: false,
              ),
            ],
          ),
          const SizedBox(height: 22),
          EcGroup(
            label: 'Your choices',
            children: [
              EcGroupRow.toggle(
                title: 'Usage analytics',
                subtitle: 'Google Analytics, on by default',
                value: prefs.usageAnalytics,
                onChanged: (v) => update((p) => p.copyWith(usageAnalytics: v)),
              ),
              EcGroupRow.toggle(
                title: 'Personalised ads',
                subtitle:
                    'Free still shows ads, just not based on your activity',
                value: prefs.personalisedAds,
                onChanged: (v) => update((p) => p.copyWith(personalisedAds: v)),
              ),
              // Where the law asks for it (EEA, UK), the consent choices made
              // on first ad can be revisited here.
              if (ref.watch(adPrivacyOptionsRequiredProvider).value ?? false)
                EcGroupRow(
                  title: 'Ad privacy choices',
                  subtitle: 'Review the consent you gave for ads',
                  onTap: () => ref.read(adServiceProvider).showPrivacyOptions(),
                ),
            ],
          ),
          const SizedBox(height: 22),
          EcGroup(
            children: [
              EcGroupRow(
                title: 'Download my data',
                subtitle: 'A .zip of projects and account info',
                onTap: () => showEcToast(context, 'Data export is coming soon'),
              ),
              EcGroupRow(
                title: 'Privacy policy',
                onTap: () => ref
                    .read(externalLinksProvider)
                    .openUrl(AppLinks.privacyPolicy),
              ),
              EcGroupRow(
                title: 'Delete account',
                destructive: true,
                onTap: () => DeleteAccountScreen.open(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// T7.2 / P7.2 — Privacy & data as a section of the tablet's Settings tab:
/// what is stored with the account in three columns, the switches, and
/// Delete account on its own red-outlined card. No ad (§5).
class PrivacyDetail extends ConsumerWidget {
  const PrivacyDetail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final prefs = (ref.watch(userProfileProvider).value ?? const UserProfile()).preferences;
    final settings = ref.read(settingsControllerProvider);
    final store = AppLinks.storeName;

    void update(Preferences Function(Preferences) change) async {
      final result = await settings.updatePreferences(change);
      if (result case Err(:final failure) when context.mounted) {
        showEcToast(context, failure.message);
      }
    }

    Widget stored(String title, String body) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.titleS.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(body, style: t.bodyS.copyWith(fontSize: 12.5, height: 1.45, color: p.muted)),
      ],
    );
    final storedItems = [
      stored('Account', 'Name, email and sign-in method'),
      stored('Projects & renders', 'Synced so they survive a new device'),
      stored('Purchases', 'Plan status only. $store handles payment.'),
      stored('Session insights', 'Microsoft Clarity records how screens are used. Emails and passwords are hidden.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(color: p.line),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('STORED WITH YOUR ACCOUNT', style: t.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.4)),
              const SizedBox(height: 10),
              for (var row = 0; row < storedItems.length; row += 3) ...[
                if (row > 0) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = row; i < row + 3; i++) ...[
                      if (i > row) const SizedBox(width: 10),
                      Expanded(child: i < storedItems.length ? storedItems[i] : const SizedBox.shrink()),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        EcGroup(
          children: [
            EcGroupRow.toggle(
              title: 'Usage analytics',
              subtitle: 'Google Analytics, on by default',
              value: prefs.usageAnalytics,
              onChanged: (v) => update((p) => p.copyWith(usageAnalytics: v)),
            ),
            EcGroupRow.toggle(
              title: 'Personalised ads',
              subtitle: 'Free still shows ads, just not based on your activity',
              value: prefs.personalisedAds,
              onChanged: (v) => update((p) => p.copyWith(personalisedAds: v)),
            ),
            if (ref.watch(adPrivacyOptionsRequiredProvider).value ?? false)
              EcGroupRow(
                title: 'Ad privacy choices',
                subtitle: 'Review the consent you gave for ads',
                onTap: () => ref.read(adServiceProvider).showPrivacyOptions(),
              ),
            EcGroupRow(
              title: 'Download my data',
              subtitle: 'A .zip of projects and account info',
              trailing: Text('Request ›', style: t.bodyS.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.accent)),
              onTap: () => showEcToast(context, 'Data export is coming soon'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: .6),
            border: Border.all(color: p.warnLine),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delete account', style: t.titleM.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: p.warn)),
                    const SizedBox(height: 3),
                    Text(
                      'Removes your account, projects and renders. If you have Pro, cancel it in $store first: '
                      'deleting the account doesn’t cancel the subscription.',
                      style: t.bodyS.copyWith(fontSize: 12.5, height: 1.45, color: p.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 46,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: p.warnWash,
                    foregroundColor: p.warn,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    textStyle: t.buttonSmall.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => DeleteAccountScreen.open(context),
                  child: const Text('Delete…'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
