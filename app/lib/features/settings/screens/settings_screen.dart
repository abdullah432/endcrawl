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
import '../../cookoo/controllers/cookoo_promo_controller.dart';
import '../../cookoo/widgets/cookoo_swiper.dart';
import '../../library/controllers/library_controller.dart';
import '../../plan/controllers/plan_controller.dart';
import '../../plan/screens/pro_sheet.dart';
import '../../plan/widgets/plan_meter.dart';
import '../controllers/settings_controller.dart';
import '../models/legal_document.dart';
import 'delete_account_screen.dart';
import 'legal_document_screen.dart';
import 'privacy_screen.dart';
import 'profile_screen.dart';
import 'subscription_screen.dart';
import '../../../core/layout/layout_class.dart';
import '../../access/controllers/web_access.dart';
import '../../access/screens/web_access_screen.dart';
import '../../home/widgets/app_side_nav.dart';

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
    final version = ref.watch(appVersionProvider).value;
    final t = context.type;
    final groups = _SettingsGroups(context, ref);

    switch (context.layoutClass) {
      case LayoutClass.expanded:
        return _DesktopSettings(groups: groups, user: user, version: version);
      case LayoutClass.medium:
        return _SplitSettings(groups: groups, user: user, version: version);
      case LayoutClass.compact:
        break;
    }

    // Rows sit in a 16 px gutter; only the COOKOO swiper runs edge to edge,
    // so its next slide can peek in.
    return EcScaffold(
      topBar: const EcTopBar(),
      scrollable: false,
      padding: EdgeInsets.zero,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Gutter(children: [
              Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 18), child: Text('Settings', style: t.displayL.copyWith(fontSize: 48))),
              if (user != null) _ProfileCard(user: user),
              const SizedBox(height: 22),
              groups.plan(),
              const SizedBox(height: 22),
              groups.defaults(),
              const SizedBox(height: 22),
              groups.app(),
              const SizedBox(height: 22),
              groups.support(),
              const SizedBox(height: 22),
              groups.legal(),
            ]),
            const CookooPromoBlock(),
            _Gutter(children: [
              const SizedBox(height: 22),
              groups.account(),
              const SizedBox(height: 18),
              groups.studio(),
              const SizedBox(height: 18),
              if (version != null) Text(version, textAlign: TextAlign.center, style: t.mono.copyWith(fontSize: 10)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// The Settings groups, built once and laid out three ways: one column on
/// the phone (7.1), a split view on a tablet (T7.1), two columns of cards
/// on a desktop browser (D15).
class _SettingsGroups {
  final BuildContext context;
  final WidgetRef ref;
  _SettingsGroups(this.context, this.ref);

  SettingsController get _settings => ref.read(settingsControllerProvider);
  Preferences get _prefs => (ref.watch(userProfileProvider).value ?? const UserProfile()).preferences;
  String? get _version => ref.watch(appVersionProvider).value;

  void _update(Preferences Function(Preferences) change) async {
    final result = await _settings.updatePreferences(change);
    if (result case Err(:final failure) when context.mounted) showEcToast(context, failure.message);
  }

  /// The plan — on the web, the subscription's status (D15): the web never
  /// sells, so it links out to Google Play and re-checks access instead.
  Widget plan() => ref.watch(runningOnWebProvider) ? const _WebPlanCard() : const _PlanCard();

  Widget defaults() {
    final prefs = _prefs;
    return EcGroup(label: 'Defaults for new projects', children: [
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
          if (fps != null) _update((p) => p.copyWith(defaultFps: fps));
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
            options: [for (final f in CanvasFormat.picker) EcOption(f.id, f.label, detail: f.sub)],
          );
          if (id != null) _update((p) => p.copyWith(defaultFormatId: id));
        },
      ),
      EcGroupRow.toggle(
        title: 'Safe-area guides',
        value: prefs.safeGuides,
        onChanged: (v) => _update((p) => p.copyWith(safeGuides: v)),
      ),
      EcGroupRow.toggle(
        title: 'Readability warnings',
        subtitle: 'Flags fast motion and names on screen under 3s',
        value: prefs.readabilityWarnings,
        onChanged: (v) => _update((p) => p.copyWith(readabilityWarnings: v)),
      ),
    ]);
  }

  Widget app() {
    final prefs = _prefs;
    return EcGroup(label: 'App', children: [
      // Light is the only theme shipped so far; the palette is a theme
      // extension, so a dark one drops in here without a rewrite.
      const EcGroupRow(title: 'Appearance', value: 'Light', chevron: false),
      EcGroupRow.toggle(title: 'Haptics', value: prefs.haptics, onChanged: (v) => _update((p) => p.copyWith(haptics: v))),
      EcGroupRow.toggle(
        title: 'Notify when a render finishes',
        value: prefs.renderNotifications,
        onChanged: (v) => _update((p) => p.copyWith(renderNotifications: v)),
      ),
    ]);
  }

  Widget support() {
    final links = ref.read(externalLinksProvider);
    final version = _version;
    return EcGroup(label: 'Support', children: [
      EcGroupRow(title: 'Help centre', onTap: () => links.openUrl(AppLinks.helpCentre)),
      EcGroupRow(
        title: 'Contact support',
        onTap: () => links.composeEmail(AppLinks.supportEmail, subject: version == null ? 'LastReel support' : '$version support'),
      ),
      EcGroupRow(title: 'Rate LastReel', onTap: _settings.rate),
    ]);
  }

  Widget legal() {
    final links = ref.read(externalLinksProvider);
    return EcGroup(label: 'Legal & privacy', children: [
      EcGroupRow(title: 'Privacy & data', onTap: () => PrivacyScreen.open(context)),
      EcGroupRow(title: 'Privacy policy', onTap: () => links.openUrl(AppLinks.privacyPolicy)),
      EcGroupRow(title: 'Terms of service', onTap: () => LegalDocumentScreen.open(context, termsOfService)),
      EcGroupRow(
        title: 'Open-source licences',
        onTap: () => showLicensePage(context: context, applicationName: 'LastReel', applicationVersion: _version),
      ),
    ]);
  }

  /// Sign out and Delete, alone at the bottom, away from everyday rows.
  Widget account() => EcGroup(children: [
        EcGroupRow(title: 'Sign out', chevron: false, onTap: signOut),
        EcGroupRow(
          title: 'Delete account',
          destructive: true,
          chevron: false,
          onTap: () => DeleteAccountScreen.open(context),
        ),
      ]);

  Future<void> signOut() async {
    // No navigation: the auth stream emits null and the gate swaps the
    // whole tree back to the welcome screen.
    final result = await _settings.signOut();
    if (result case Err(:final failure) when context.mounted) showEcToast(context, failure.message);
  }

  Widget studio() {
    final links = ref.read(externalLinksProvider);
    return EcGroup(children: [
      EcGroupRow(title: 'Made by COOKOO', onTap: () => links.openUrl(AppLinks.studio)),
      EcGroupRow.toggle(
        title: 'Show COOKOO studio card',
        value: !ref.watch(cookooPromoProvider.select((s) => s.hidden)),
        onChanged: ref.read(cookooPromoProvider.notifier).setShown,
      ),
    ]);
  }
}

enum _Section { plan, defaults, app, support, legal, studio }

extension on _Section {
  String get title => switch (this) {
        _Section.plan => 'Plan',
        _Section.defaults => 'Defaults',
        _Section.app => 'App',
        _Section.support => 'Support',
        _Section.legal => 'Privacy & legal',
        _Section.studio => 'COOKOO',
      };

  Widget body(_SettingsGroups groups) => switch (this) {
        _Section.plan => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [groups.plan(), const SizedBox(height: 18), groups.defaults()],
          ),
        _Section.defaults => groups.defaults(),
        _Section.app => groups.app(),
        _Section.support => groups.support(),
        _Section.legal => groups.legal(),
        _Section.studio => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [const CookooPromoBlock(), const SizedBox(height: 18), groups.studio()],
          ),
      };
}

/// T7.1 / T7.2 — a split view: the list stays, the detail changes. Ordered
/// by how often each is needed; Sign out and Delete sit alone at the
/// bottom of the list.
class _SplitSettings extends StatefulWidget {
  final _SettingsGroups groups;
  final AppUser? user;
  final String? version;
  const _SplitSettings({required this.groups, required this.user, required this.version});

  @override
  State<_SplitSettings> createState() => _SplitSettingsState();
}

class _SplitSettingsState extends State<_SplitSettings> {
  _Section _selected = _Section.plan;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final user = widget.user;
    Widget item(String title, {bool selected = false, bool destructive = false, required VoidCallback onTap}) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: selected ? p.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: t.row.copyWith(
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: destructive ? p.warn : p.ink,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 18, color: p.faint),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: EcGround(
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 300,
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .3),
                  border: Border(right: BorderSide(color: p.line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        EcCircleButton.glass(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Semantics(
                            header: true,
                            child: Text(
                              'Settings',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.displayM.copyWith(fontSize: 30),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (user != null) ...[_ProfileCard(user: user), const SizedBox(height: 14)],
                    Expanded(
                      child: ListView(
                        children: [
                          for (final section in _Section.values)
                            item(section.title, selected: section == _selected, onTap: () => setState(() => _selected = section)),
                          const SizedBox(height: 8),
                          item('Sign out', onTap: widget.groups.signOut),
                          item('Delete account', destructive: true, onTap: () => DeleteAccountScreen.open(context)),
                        ],
                      ),
                    ),
                    if (widget.version != null) Text(widget.version!, style: t.mono.copyWith(fontSize: 10)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
                  child: KeyedSubtree(key: ValueKey(_selected), child: _selected.body(widget.groups)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D15 — Settings in the desktop rail: the subscription and account on the
/// left, defaults, app and the rest on the right.
class _DesktopSettings extends StatelessWidget {
  final _SettingsGroups groups;
  final AppUser? user;
  final String? version;
  const _DesktopSettings({required this.groups, required this.user, required this.version});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final user = this.user;
    const gap = SizedBox(height: 16);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: EcGround(
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSideNav(
                selected: HomeDestination.settings,
                onSelect: (_) => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(44, 34, 44, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(header: true, child: Text('Settings', style: t.displayXL.copyWith(fontSize: 52))),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                groups.plan(),
                                gap,
                                if (user != null) ...[_ProfileCard(user: user), gap],
                                groups.support(),
                                gap,
                                groups.studio(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                groups.defaults(),
                                gap,
                                groups.app(),
                                gap,
                                groups.legal(),
                                gap,
                                groups.account(),
                                if (version != null) ...[
                                  const SizedBox(height: 14),
                                  Text(version!, textAlign: TextAlign.center, style: t.mono.copyWith(fontSize: 10)),
                                ],
                              ],
                            ),
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
      ),
    );
  }
}

/// D15's subscription card: status only. Pro links out to Google Play to
/// manage it and offers a re-check for a renewal that just went through;
/// Free leads to how to get Pro. If Pro ends, nothing is deleted — the web
/// goes back to preview.
class _WebPlanCard extends ConsumerWidget {
  const _WebPlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final pro = ref.watch(entitlementProvider).value?.isPro ?? false;
    final user = ref.watch(authStateProvider).value;
    final checking = ref.watch(accessCheckProvider.select((c) => c.phase == AccessPhase.checking));
    Widget chip(String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_rounded, size: 14, color: p.ok),
              const SizedBox(width: 6),
              Text(label, style: t.bodyS.copyWith(fontSize: 12)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(EcRadius.group),
        boxShadow: p.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('SUBSCRIPTION', style: t.eyebrow.copyWith(fontSize: 9.5))),
              if (pro) EcStatusPill('Active', tone: EcTone.ok),
            ],
          ),
          const SizedBox(height: 10),
          Text(pro ? 'LastReel Pro' : 'Free · web preview', style: t.displayM.copyWith(fontSize: 32)),
          const SizedBox(height: 4),
          Text(
            pro
                ? '${user?.email ?? 'This account'} · billed through Google Play'
                : 'Open and play any project here. Editing, new projects and export unlock with Pro.',
            style: t.bodyS.copyWith(color: p.ink2),
          ),
          const SizedBox(height: 14),
          if (pro) ...[
            Wrap(spacing: 8, runSpacing: 8, children: [chip('Web & desktop'), chip('Every format'), chip('No ads')]),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (pro)
                EcButton(
                  label: 'Manage in Google Play',
                  variant: EcButtonVariant.ink,
                  size: EcButtonSize.medium,
                  expand: false,
                  leading: Icon(Icons.open_in_new_rounded, size: 15, color: p.onInk),
                  onPressed: () => ref.read(externalLinksProvider).openUrl(AppLinks.playSubscriptions),
                )
              else
                EcButton(
                  label: 'How to get Pro',
                  variant: EcButtonVariant.ink,
                  size: EcButtonSize.medium,
                  expand: false,
                  onPressed: () => WebAccessScreen.open(context),
                ),
              EcButton.secondary(
                label: 'Re-check access',
                size: EcButtonSize.medium,
                expand: false,
                busy: checking,
                onPressed: () => ref.read(accessCheckProvider.notifier).check(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Renewal date, price and cancellation live in your Google Play account. If Pro ends, nothing is deleted; '
            'the web goes back to preview.',
            style: t.fine.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// A run of Settings content inside the 16 px side gutter.
class _Gutter extends StatelessWidget {
  final List<Widget> children;
  const _Gutter({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
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
      onTap: () => ProfileScreen.open(context),
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
          Icon(Icons.chevron_right_rounded, color: p.faint),
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
    final status = switch ((entitlement.trialEndsAt, limit)) {
      (final ends?, _) => 'Pro trial · ends ${formatDayMonth(ends)}',
      (_, null) => '${plural(count, 'project')} · no ads',
      (_, final limit?) => '$count of ${plural(limit, 'project')} · ads on',
    };
    final upgradeLabel = plan.offers.any((o) => o.hasTrial) ? 'Start free trial' : 'Upgrade to Pro';
    Future<void> restore() async {
      await ref.read(planControllerProvider.notifier).restore();
      final message = ref.read(planControllerProvider).message;
      if (message != null && context.mounted) showEcToast(context, message);
    }

    // T7.1 — on a tablet the plan leads the detail pane as a full card.
    final card = context.layoutClass.isWide
        ? Container(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(EcRadius.group),
              boxShadow: p.glassShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('PLAN', style: t.eyebrow.copyWith(fontSize: 9.5))),
                    Text(status.toUpperCase(), style: t.eyebrow.copyWith(fontSize: 9.5)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(entitlement.isPro ? 'LastReel Pro' : 'Free', style: t.displayM.copyWith(fontSize: 36)),
                if (limit != null) ...[
                  const SizedBox(height: 14),
                  PlanMeter(used: count.clamp(0, limit), limit: limit),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      EcButton(
                        label: upgradeLabel,
                        variant: EcButtonVariant.ink,
                        size: EcButtonSize.medium,
                        expand: false,
                        onPressed: () => ProSheet.show(context, source: PlanSource.settings),
                      ),
                      EcButton.secondary(
                        label: 'Restore purchase',
                        size: EcButtonSize.medium,
                        expand: false,
                        busy: plan.restoring,
                        onPressed: plan.busy ? null : restore,
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text('Manage your subscription', style: t.bodyS.copyWith(color: p.ink2))),
                      Icon(Icons.chevron_right_rounded, color: p.faint),
                    ],
                  ),
                ],
              ],
            ),
          )
        : Container(
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
                child: Text(entitlement.isPro ? 'LastReel Pro' : 'Free plan',
                    style: t.titleM.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
              Text(status, style: t.mono.copyWith(fontSize: 10)),
            ],
          ),
          if (limit != null) ...[
            const SizedBox(height: 12),
            PlanMeter(used: count.clamp(0, limit), limit: limit),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: EcButton(
                    label: upgradeLabel,
                    size: EcButtonSize.medium,
                    onPressed: () => ProSheet.show(context, source: PlanSource.settings),
                  ),
                ),
                const SizedBox(width: 8),
                EcButton.secondary(
                  label: 'Restore',
                  size: EcButtonSize.medium,
                  busy: plan.restoring,
                  onPressed: plan.busy ? null : restore,
                ),
              ],
            ),
          ],
        ],
      ),
    );
    // On Pro the card is the way into the subscription (7.3); on Free its
    // buttons lead to the Pro sheet instead.
    if (!entitlement.isPro) return card;
    return Semantics(
      button: true,
      child: GestureDetector(onTap: () => SubscriptionScreen.open(context), child: card),
    );
  }
}
