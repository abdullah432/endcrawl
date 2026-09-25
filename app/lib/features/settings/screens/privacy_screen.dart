import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_settings.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/user_profile.dart';
import '../../ads/ads_providers.dart';
import '../controllers/settings_controller.dart';
import '../models/legal_document.dart';
import 'delete_account_screen.dart';
import 'legal_document_screen.dart';

/// 7.4 — plain language about what is kept, three switches with honest
/// defaults, and a way out.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final prefs = (ref.watch(userProfileProvider).value ?? const UserProfile()).preferences;
    final settings = ref.read(settingsControllerProvider);

    void update(Preferences Function(Preferences) change) async {
      final result = await settings.updatePreferences(change);
      if (result case Err(:final failure) when context.mounted) showEcToast(context, failure.message);
    }

    return EcScaffold(
      topBar: const EcTopBar(title: 'Privacy & data'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
            child: EcHeadline('What we keep, and ', emphasis: 'what you control.', style: t.displayM),
          ),
          const EcGroup(label: 'Stored with your account', children: [
            EcGroupRow(title: 'Account', subtitle: 'Name, email and sign-in method', chevron: false),
            EcGroupRow(title: 'Projects & renders', subtitle: 'Synced so they survive a new phone', chevron: false),
            EcGroupRow(title: 'Purchases', subtitle: 'Plan status only. Apple handles payment.', chevron: false),
          ]),
          const SizedBox(height: 22),
          EcGroup(label: 'Your choices', children: [
            EcGroupRow.toggle(
              title: 'Crash reports',
              subtitle: 'Helps us fix failed renders',
              value: prefs.crashReports,
              onChanged: (v) => update((p) => p.copyWith(crashReports: v)),
            ),
            EcGroupRow.toggle(
              title: 'Usage analytics',
              subtitle: 'Anonymous and off by default',
              value: prefs.usageAnalytics,
              onChanged: (v) => update((p) => p.copyWith(usageAnalytics: v)),
            ),
            EcGroupRow.toggle(
              title: 'Personalised ads',
              subtitle: 'Free still shows ads, just not based on your activity',
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
          ]),
          const SizedBox(height: 22),
          EcGroup(children: [
            EcGroupRow(
              title: 'Download my data',
              subtitle: 'A .zip of projects and account info',
              onTap: () => showEcToast(context, 'Data export is coming soon'),
            ),
            EcGroupRow(title: 'Privacy policy', onTap: () => LegalDocumentScreen.open(context, privacyPolicy)),
            EcGroupRow(title: 'Delete account', destructive: true, onTap: () => DeleteAccountScreen.open(context)),
          ]),
        ],
      ),
    );
  }
}
