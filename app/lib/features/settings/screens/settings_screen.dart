import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/result.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_option_sheet.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_settings.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/app_user.dart';
import '../../../domain/models/canvas_format.dart';
import '../../../domain/models/entitlement.dart';
import '../../../domain/models/user_profile.dart';
import '../../library/controllers/library_controller.dart';
import '../../plan/controllers/plan_controller.dart';
import '../../plan/screens/pro_sheet.dart';
import '../../plan/widgets/plan_meter.dart';
import '../controllers/settings_controller.dart';
import '../models/legal_document.dart';
import 'legal_document_screen.dart';

/// 7.1 — Settings.
///
/// Ordered by how often people need each thing: who you are, your plan,
/// project defaults, then support and legal. Sign out and Delete sit alone
/// at the bottom, away from everyday rows.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final prefs = (ref.watch(userProfileProvider).value ?? const UserProfile()).preferences;
    final settings = ref.read(settingsControllerProvider);
    final links = ref.read(externalLinksProvider);
    final version = ref.watch(appVersionProvider).value;
    final t = context.type;

    void update(Preferences Function(Preferences) change) async {
      final result = await settings.updatePreferences(change);
      if (result case Err(:final failure) when context.mounted) showEcToast(context, failure.message);
    }

    return EcScaffold(
      topBar: const EcTopBar(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 34),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 18), child: Text('Settings', style: t.displayL.copyWith(fontSize: 48))),
          if (user != null) _ProfileCard(user: user),
          const SizedBox(height: 22),
          const _PlanCard(),
          const SizedBox(height: 22),
          EcGroup(label: 'Defaults for new projects', children: [
            EcGroupRow(
              title: 'Frame rate',
              value: formatFps(prefs.defaultFps),
              onTap: () async {
                final fps = await EcOptionSheet.show<double>(
                  context,
                  title: 'Frame rate',
                  selected: prefs.defaultFps,
                  options: [for (final f in kFrameRates) EcOption(f, formatFps(f))],
                );
                if (fps != null) update((p) => p.copyWith(defaultFps: fps));
              },
            ),
            EcGroupRow(
              title: 'Canvas',
              value: CanvasFormat.byId(prefs.defaultFormatId).label,
              onTap: () async {
                final id = await EcOptionSheet.show<String>(
                  context,
                  title: 'Canvas',
                  selected: prefs.defaultFormatId,
                  options: [for (final f in CanvasFormat.presets) EcOption(f.id, f.label, detail: f.sub)],
                );
                if (id != null) update((p) => p.copyWith(defaultFormatId: id));
              },
            ),
            EcGroupRow.toggle(
              title: 'Safe-area guides',
              value: prefs.safeGuides,
              onChanged: (v) => update((p) => p.copyWith(safeGuides: v)),
            ),
            EcGroupRow.toggle(
              title: 'Readability warnings',
              subtitle: 'Flags judder and names on screen under 3s',
              value: prefs.readabilityWarnings,
              onChanged: (v) => update((p) => p.copyWith(readabilityWarnings: v)),
            ),
          ]),
          const SizedBox(height: 22),
          EcGroup(label: 'App', children: [
            // Light is the only theme shipped so far; the palette is a theme
            // extension, so a dark one drops in here without a rewrite.
            const EcGroupRow(title: 'Appearance', value: 'Light', chevron: false),
            EcGroupRow.toggle(title: 'Haptics', value: prefs.haptics, onChanged: (v) => update((p) => p.copyWith(haptics: v))),
            EcGroupRow.toggle(
              title: 'Notify when a render finishes',
              value: prefs.renderNotifications,
              onChanged: (v) => update((p) => p.copyWith(renderNotifications: v)),
            ),
          ]),
          const SizedBox(height: 22),
          EcGroup(label: 'Support', children: [
            EcGroupRow(title: 'Help centre', onTap: () => links.openUrl(AppLinks.helpCentre)),
            EcGroupRow(
              title: 'Contact support',
              onTap: () => links.composeEmail(AppLinks.supportEmail, subject: version == null ? 'EndCrawl support' : '$version support'),
            ),
            EcGroupRow(title: 'Rate EndCrawl', onTap: settings.rate),
          ]),
          const SizedBox(height: 22),
          EcGroup(label: 'Legal & privacy', children: [
            EcGroupRow(title: 'Privacy policy', onTap: () => LegalDocumentScreen.open(context, privacyPolicy)),
            EcGroupRow(title: 'Terms of service', onTap: () => LegalDocumentScreen.open(context, termsOfService)),
            EcGroupRow(
              title: 'Open-source licences',
              onTap: () => showLicensePage(context: context, applicationName: 'EndCrawl', applicationVersion: version),
            ),
          ]),
          const SizedBox(height: 22),
          EcGroup(children: [
            EcGroupRow(
              title: 'Sign out',
              chevron: false,
              onTap: () async {
                // No navigation: the auth stream emits null and the gate
                // swaps the whole tree back to the welcome screen.
                final result = await settings.signOut();
                if (result case Err(:final failure) when context.mounted) showEcToast(context, failure.message);
              },
            ),
          ]),
          const SizedBox(height: 18),
          if (version != null) Text(version, textAlign: TextAlign.center, style: t.mono.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AppUser user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final method = user.primaryMethod;
    return EcGlassCard(
      strong: true,
      radius: EcRadius.group,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          EcAvatar(initials: user.initials, size: 56, gradient: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.label, style: t.titleM.copyWith(fontSize: 16.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (user.email != null && user.email != user.label) ...[
                  const SizedBox(height: 2),
                  Text(user.email!, style: t.bodyS.copyWith(color: p.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (method != null) ...[
                  const SizedBox(height: 7),
                  EcStatusPill(method == SignInMethod.password ? 'Signed in with email' : 'Signed in with ${method.label}'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final entitlement = ref.watch(entitlementProvider).value ?? const Entitlement.free();
    final count = ref.watch(projectSummariesProvider).value?.length ?? 0;
    final plan = ref.watch(planControllerProvider);
    final limit = entitlement.projectLimit;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.accentLine),
        borderRadius: BorderRadius.circular(EcRadius.group),
        boxShadow: const [BoxShadow(color: Color(0x800C6EC8), offset: Offset(0, 14), blurRadius: 30, spreadRadius: -22)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(entitlement.isPro ? 'EndCrawl Pro' : 'Free plan',
                    style: t.titleM.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
              Text(
                limit == null ? '$count projects · no ads' : '$count of $limit projects · ads on',
                style: t.mono.copyWith(fontSize: 10),
              ),
            ],
          ),
          if (limit != null) ...[
            const SizedBox(height: 12),
            PlanMeter(used: count.clamp(0, limit), limit: limit),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: EcButton(label: 'Upgrade to Pro', size: EcButtonSize.medium, onPressed: () => ProSheet.show(context))),
                const SizedBox(width: 8),
                EcButton.secondary(
                  label: 'Restore',
                  size: EcButtonSize.medium,
                  busy: plan.restoring,
                  onPressed: plan.busy
                      ? null
                      : () async {
                          await ref.read(planControllerProvider.notifier).restore();
                          final message = ref.read(planControllerProvider).message;
                          if (message != null && context.mounted) showEcToast(context, message);
                        },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
