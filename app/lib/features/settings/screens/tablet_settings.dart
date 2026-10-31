import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/ec_type.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_settings.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/app_user.dart';
import '../../../domain/models/entitlement.dart';
import '../../cookoo/widgets/cookoo_swiper.dart';
import '../../desk/desk_invite.dart';
import '../../home/tablet_layout.dart';
import '../../home/widgets/app_side_nav.dart';
import '../../library/controllers/library_controller.dart';
import '../../plan/controllers/plan_controller.dart';
import '../../plan/screens/pro_sheet.dart';
import '../../plan/widgets/plan_meter.dart';
import '../../plan/controllers/release_policy.dart';
import '../controllers/settings_controller.dart';
import 'delete_account_screen.dart';
import 'privacy_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';

/// T7.1 / T7.2 · P7.1 / P7.2 — the Settings tab on a tablet.
///
/// Landscape: a 300-wide section list beside the rail, the detail filling
/// the rest. Picking a section swaps only the detail; there is no back
/// button, because you never left. Portrait: a full page — account and
/// plan, then the sections, Sign out and Delete — and a section opens one
/// level deeper with "‹ Settings".
///
/// Settings carries no ads (T8.3), so nothing competes with the COOKOO
/// tile in From the makers.
///
/// The open section lives in [settingsSectionProvider], so it survives
/// rotation and is remembered for the session; in portrait, Plan is the
/// page itself.
class TabletSettings extends ConsumerWidget {
  const TabletSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = SettingsGroups(context, ref);
    final section = ref.watch(settingsSectionProvider);
    return EcTabletSettings(
      child: context.tabletLayout == TabletLayout.portrait
          ? _PortraitSettings(groups: groups, section: section)
          : _LandscapeSettings(groups: groups, section: section),
    );
  }
}

void _open(WidgetRef ref, SettingsSection section) {
  ref.read(settingsSectionProvider.notifier).select(section);
  ref.read(analyticsProvider).logEvent('settings_section_opened', {'section': section.id});
}

String _subtitle(SettingsSection section) => switch (section) {
  SettingsSection.plan => 'Your account and plan.',
  SettingsSection.defaults => 'For every new project.',
  SettingsSection.app => 'Appearance, haptics, notifications.',
  SettingsSection.support => 'Help, contact, rate LastReel.',
  SettingsSection.makers => 'COOKOO, the team behind LastReel.',
  SettingsSection.privacy => 'What we keep, and what you control.',
  SettingsSection.legal => 'Terms, privacy policy, licences.',
};

/// A section's content, the same in both orientations.
Widget _body(SettingsGroups groups, SettingsSection section) {
  const gap = SizedBox(height: 16);
  return switch (section) {
    SettingsSection.plan => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const _AccountPlanCard(portrait: false), gap, groups.defaults(brief: true)],
    ),
    SettingsSection.defaults => groups.defaults(),
    SettingsSection.app => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        groups.app(),
        if (groups.testerAllowed) ...[gap, groups.tester()],
      ],
    ),
    SettingsSection.support => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [groups.support(), const _Version()],
    ),
    // T9.1: one COOKOO tile at a time, the next peeking, then the team's
    // other apps. Shown on Free and Pro; it is a paid service, not an ad.
    SettingsSection.makers => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CookooPromoBlock(counter: true),
        if (groups.hasOtherApps) ...[const SizedBox(height: 22), groups.otherApps()],
      ],
    ),
    SettingsSection.privacy => const PrivacyDetail(),
    SettingsSection.legal => groups.legalLinks(),
  };
}

// ---------- landscape (T7.1, T7.2) ----------

class _LandscapeSettings extends ConsumerWidget {
  final SettingsGroups groups;
  final SettingsSection section;
  const _LandscapeSettings({required this.groups, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    Widget item(String label, {bool selected = false, bool destructive = false, required VoidCallback onTap}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Semantics(
            selected: selected,
            button: true,
            child: Material(
              color: selected ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: t.row.copyWith(
                            fontSize: 14,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: destructive ? p.warn : p.ink,
                          ),
                        ),
                      ),
                      Text('›', style: t.row.copyWith(color: p.faint)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(14, 32, 14, 20),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: p.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
                child: Semantics(header: true, child: Text('Settings', style: t.displayL.copyWith(fontSize: 40))),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final s in SettingsSection.values)
                      item(s.title, selected: s == section, onTap: () => _open(ref, s)),
                    item('Sign out', onTap: groups.signOut),
                    item('Delete account', destructive: true, onTap: () => DeleteAccountScreen.open(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (section == SettingsSection.plan)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text('PLAN', style: t.eyebrow.copyWith(fontSize: 10.5, letterSpacing: 10.5 * .14)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _Heading(section: section, size: 34),
                  ),
                KeyedSubtree(key: ValueKey(section), child: _body(groups, section)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  final SettingsSection section;
  final double size;
  const _Heading({required this.section, required this.size});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(section.title, style: t.displayL.copyWith(fontSize: size)),
        ),
        SizedBox(height: size > 36 ? 8 : 6),
        Text(
          _subtitle(section),
          style: t.body.copyWith(fontSize: size > 36 ? 14 : 13.5, color: context.palette.muted),
        ),
      ],
    );
  }
}

// ---------- portrait (P7.1, P7.2) ----------

class _PortraitSettings extends ConsumerWidget {
  final SettingsGroups groups;
  final SettingsSection section;
  const _PortraitSettings({required this.groups, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final root = section == SettingsSection.plan;
    return PopScope(
      // Back from a section returns to the Settings page, not out of it.
      // Only while Settings is the tab showing; hidden, it keeps out of Back.
      canPop: root || ref.watch(homeTabProvider) != HomeDestination.settings,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(settingsSectionProvider.notifier).select(SettingsSection.plan);
      },
      child: root ? _PortraitRoot(groups: groups) : _PortraitSection(groups: groups, section: section),
    );
  }
}

class _PortraitRoot extends ConsumerWidget {
  final SettingsGroups groups;
  const _PortraitRoot({required this.groups});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final sections = [
      (SettingsSection.defaults, 'Defaults for new projects', groups.defaultsSummary()),
      (SettingsSection.app, 'App', 'Appearance, haptics, notifications'),
      (SettingsSection.support, 'Support', 'Help, contact, rate LastReel'),
      (SettingsSection.makers, 'From the makers', 'COOKOO, the team behind LastReel'),
      (SettingsSection.privacy, 'Privacy & data', 'Analytics, ads, download your data'),
      (SettingsSection.legal, 'Legal', 'Terms, privacy policy, licences'),
    ];
    Widget card(List<Widget> rows) => Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, color: p.line, indent: 22, endIndent: 22),
              rows[i],
            ],
          ],
        ),
      ),
    );
    Widget row({required String title, String? subtitle, bool destructive = false, required VoidCallback onTap}) =>
        InkWell(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: subtitle == null ? 54 : 58),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: t.row.copyWith(
                          fontSize: 15,
                          fontWeight: destructive ? FontWeight.w600 : FontWeight.w500,
                          color: destructive ? p.warn : p.ink,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: t.caption.copyWith(fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                if (subtitle != null) Text('›', style: t.row.copyWith(fontSize: 18, color: p.faint)),
              ],
            ),
          ),
        );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
          sliver: SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text('Settings', style: t.displayL.copyWith(fontSize: 42))),
                const SizedBox(height: 14),
                const _AccountPlanCard(portrait: true),
                const SizedBox(height: 14),
                card([
                  for (final (section, title, subtitle) in sections)
                    row(title: title, subtitle: subtitle, onTap: () => _open(ref, section)),
                ]),
                const SizedBox(height: 14),
                card([
                  row(title: 'Sign out', onTap: groups.signOut),
                  row(title: 'Delete account', destructive: true, onTap: () => DeleteAccountScreen.open(context)),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// P7.2: one level in from the Settings page. The tab bar stays, and the
/// Settings ad sits below the section's content.
class _PortraitSection extends ConsumerWidget {
  final SettingsGroups groups;
  final SettingsSection section;
  const _PortraitSection({required this.groups, required this.section});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    return SingleChildScrollView(
      key: ValueKey(section),
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Back to Settings',
              excludeSemantics: true,
              child: Material(
                color: p.surface,
                shape: StadiumBorder(side: BorderSide(color: p.line)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => ref.read(settingsSectionProvider.notifier).select(SettingsSection.plan),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.fromLTRB(10, 0, 16, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chevron_left_rounded, size: 20, color: p.ink),
                        const SizedBox(width: 2),
                        Text('Settings', style: t.buttonSmall.copyWith(fontSize: 13.5)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Heading(section: section, size: 42),
          const SizedBox(height: 14),
          _body(groups, section),
        ],
      ),
    );
  }
}

// ---------- shared ----------

/// T7.1 / P7.1: who you are and your plan, on one card. Edit opens the
/// profile; "See LastReel Pro" the Pro screen (T6.3). Pro and trials show
/// their status and the way into the subscription instead.
class _AccountPlanCard extends ConsumerWidget {
  final bool portrait;
  const _AccountPlanCard({required this.portrait});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final user = ref.watch(authStateProvider).value;
    final freeLaunch = ref.watch(iosFreeLaunchProvider);
    final entitlement = ref.watch(entitlementProvider).value ?? const Entitlement.free();
    final count = ref.watch(projectSummariesProvider).value?.length ?? 0;
    final plan = ref.watch(planControllerProvider);
    final limit = entitlement.projectLimit;
    final status = switch ((entitlement.trialEndsAt, limit)) {
      (final ends?, _) => 'Pro trial · ends ${formatDayMonth(ends)}',
      (_, null) => '${plural(count, 'project')} · no ads',
      (_, final limit?) => '${count.clamp(0, limit)} of ${plural(limit, 'project')} · ads on',
    };
    final planName = entitlement.isPro ? 'Pro' : 'Free';
    final eyebrow = t.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.4);

    Future<void> restore() async {
      await ref.read(planControllerProvider.notifier).restore();
      final message = ref.read(planControllerProvider).message;
      if (message != null && context.mounted) showEcToast(context, message);
    }

    final primary = entitlement.isPro
        ? EcButton.secondary(
            label: 'Manage subscription',
            size: EcButtonSize.medium,
            height: portrait ? 46 : 48,
            expand: false,
            onPressed: () => SubscriptionScreen.open(context),
          )
        : EcButton(
            label: 'See LastReel Pro',
            variant: EcButtonVariant.ink,
            size: EcButtonSize.medium,
            height: portrait ? 46 : 48,
            expand: false,
            onPressed: () => ProSheet.show(context, source: PlanSource.settings),
          );
    final restoreButton = EcButton.secondary(
      label: 'Restore purchase',
      size: EcButtonSize.medium,
      height: 48,
      expand: false,
      busy: plan.restoring,
      onPressed: plan.busy ? null : restore,
    );
    final web = entitlement.isPro
        ? 'LastReel on the web is included with your Pro, on this same account.'
        : 'Working at a computer? LastReel on the web is included with Pro, on this same account.';

    return Container(
      padding: portrait ? const EdgeInsets.symmetric(horizontal: 22, vertical: 20) : const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(24),
        boxShadow: p.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (user != null) _AccountRow(user: user, portrait: portrait),
          if (!freeLaunch) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: p.line),
            const SizedBox(height: 14),
            if (portrait) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(caps('Plan · $planName'), style: eyebrow)),
                            Text(caps(status), style: eyebrow),
                          ],
                        ),
                        if (limit != null) ...[
                          const SizedBox(height: 8),
                          PlanMeter(used: count.clamp(0, limit), limit: limit, thickness: 5, gap: 4, fill: p.ink),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  primary,
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (!entitlement.isPro)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 36),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: plan.busy ? null : restore,
                      child: Text('Restore purchase', style: t.buttonSmall.copyWith(fontSize: 13, color: p.accent)),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => DeskInvite.showNow(context),
                    child: Text(
                      entitlement.isPro ? 'LastReel on the web is included' : 'LastReel on the web comes with Pro',
                      style: t.body.copyWith(fontSize: 13, color: p.muted),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(child: Text('PLAN', style: eyebrow)),
                  Text(caps(status), style: eyebrow),
                ],
              ),
              const SizedBox(height: 14),
              Text(entitlement.isPro ? 'LastReel Pro' : 'Free', style: t.displayM.copyWith(fontSize: 36)),
              if (limit != null) ...[
                const SizedBox(height: 14),
                PlanMeter(used: count.clamp(0, limit), limit: limit, thickness: 5, gap: 4, fill: p.ink),
              ],
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [primary, if (!entitlement.isPro) restoreButton]),
              const SizedBox(height: 14),
              Material(
                color: p.sheet,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => DeskInvite.showNow(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.desktop_windows_outlined, size: 18, color: p.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(web, style: t.body.copyWith(fontSize: 13, height: 1.45, color: p.ink2)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final AppUser user;
  final bool portrait;
  const _AccountRow({required this.user, required this.portrait});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final size = portrait ? 48.0 : 44.0;
    return Row(
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.sheet,
            shape: BoxShape.circle,
            border: Border.all(color: p.line),
          ),
          child: Text(user.initials, style: t.titleS.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.titleM.copyWith(fontSize: portrait ? 15.5 : 15, fontWeight: FontWeight.w700),
              ),
              if (user.email != null && user.email != user.label)
                Text(
                  user.email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyS.copyWith(fontSize: portrait ? 12.5 : 12, color: p.muted),
                ),
            ],
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          onPressed: () => ProfileScreen.open(context),
          child: Text('Edit', style: t.buttonSmall.copyWith(fontSize: 13, color: p.accent)),
        ),
      ],
    );
  }
}

class _Version extends ConsumerWidget {
  const _Version();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value;
    if (version == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Text(
        version,
        textAlign: TextAlign.center,
        style: context.type.mono.copyWith(fontSize: 10, color: context.palette.muted),
      ),
    );
  }
}
