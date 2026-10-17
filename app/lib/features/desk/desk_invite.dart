import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../bootstrap.dart';
import '../../core/config/app_links.dart';
import '../../core/theme/ec_type.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/ec_button.dart';
import '../../core/widgets/ec_fields.dart';
import '../../core/widgets/ec_headline.dart';
import '../../core/widgets/ec_scaffold.dart';
import '../../core/widgets/ec_sheet.dart';
import '../../core/widgets/ec_toast.dart';
import '../access/controllers/web_access.dart';
import '../library/controllers/library_controller.dart';
import '../plan/controllers/plan_controller.dart';
import '../plan/screens/pro_sheet.dart';
import '../review/review_prompt.dart';
import '../tester/tester_mode.dart';
import 'desk_invite_store.dart';

/// Overridden in `main` with the SharedPreferences-backed store, and in
/// tests with an in-memory one.
final deskInviteStoreProvider = Provider<DeskInviteStore>((ref) {
  throw StateError('deskInviteStoreProvider was not overridden — see bootstrap().');
});

/// Set once the invite has had its chance this run of the app — shown, or
/// passed over by the roll — so it is decided at most once per session.
final deskInviteShownThisSessionProvider = NotifierProvider<ShownThisSession, bool>(ShownThisSession.new);

/// True from the moment the invite opens until its follow-up (the Pro
/// sheet, the mail app) is done.
final deskInviteOpenProvider = NotifierProvider<DeskInviteOpen, bool>(DeskInviteOpen.new);

class DeskInviteOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) => state = open;
}

/// The roll behind "by chance": true one session in [DeskInvite.chanceOneIn]
/// once the invite is due. Tests replace it with a sure thing.
final deskInviteChanceProvider = Provider<bool Function()>((ref) {
  final random = Random();
  return () => random.nextInt(DeskInvite.chanceOneIn) == 0;
});

enum _DeskAction { upgrade, preview, email, copy, later }

/// What the person picked on the sheet, and the two things they can set on
/// it before they leave by any way at all.
class _DeskChoices {
  _DeskAction action = _DeskAction.later;
  bool neverAgain = false;
  String to;
  _DeskChoices(this.to);
}

/// 1.8a / 1.8b — "LastReel on a big screen", raised on the library.
///
/// Free (1.8a) sells the upgrade, since the desk editor is part of Pro, and
/// can preview the web app first; Pro (1.8b) gets the web app's link to a
/// computer, by their own email app or the clipboard.
///
/// When it shows, as the design's notes have it: by chance on opening the
/// library (one session in [chanceOneIn] once it is due), never mid-edit or
/// during export, not in the first [firstSessions] sessions, at most once
/// every 30 days, never in the same session as the rating prompt, never on
/// the web (that is the desk), and never again after "Don't show this
/// again" — tester accounts included. A tester can raise it on demand from
/// Settings › Tester ([showNow]) without touching that schedule.
abstract final class DeskInvite {
  static const quiet = Duration(days: 30);
  static const firstSessions = 3;
  static const chanceOneIn = 3;

  static bool due({
    required DeskInviteStore store,
    required DateTime now,
    required bool ratedThisSession,
    required bool web,
  }) {
    if (web || store.turnedOff || ratedThisSession) return false;
    if (store.sessions <= firstSessions) return false;
    final until = store.quietUntil;
    return until == null || !now.isBefore(until);
  }

  /// Called from the library's build: only while the library itself is on
  /// top (never over the editor or an export), and after the frame, since
  /// providers can't change mid-build.
  static void check(BuildContext context, LibraryView? view) {
    if (view == null) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _checkSoon(context);
  }

  static void _checkSoon(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? true)) maybeShow(context);
    });
  }

  /// Settings › Tester: the invite now, for this plan, whatever the schedule
  /// — and without moving it, so real users' 30-day rhythm is what ships.
  static Future<void> showNow(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final view = container.read(libraryViewProvider).value;
    if (view == null) return;
    await _show(context, container, view, container.read(deskInviteStoreProvider), container.read(clockProvider)(),
        countIt: false);
  }

  static Future<void> maybeShow(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final store = container.read(deskInviteStoreProvider);
    // The plan reads as Free until the store (and, for a tester, Firestore)
    // answers, and changes under a library still showing the old one: wait
    // for all three to settle, or a Pro library would be sold Pro.
    bool settled(AsyncValue<Object?> value) => value.hasValue && !value.isLoading;
    final latest = container.read(libraryViewProvider);
    if (!settled(container.read(entitlementProvider)) || !settled(container.read(testerAllowedProvider)) || !settled(latest)) {
      return;
    }
    final view = latest.requireValue;
    final now = container.read(clockProvider)();
    if (container.read(deskInviteShownThisSessionProvider) ||
        container.read(deskInviteOpenProvider) ||
        !due(
          store: store,
          now: now,
          ratedThisSession: container.read(reviewPromptShownThisSessionProvider),
          web: container.read(runningOnWebProvider),
        )) {
      return;
    }
    // One roll per session: a library opened again doesn't get another.
    container.read(deskInviteShownThisSessionProvider.notifier).mark();
    if (!container.read(deskInviteChanceProvider)()) return;
    container.read(deskInviteOpenProvider.notifier).set(true);
    try {
      await _show(context, container, view, store, now);
    } finally {
      container.read(deskInviteOpenProvider.notifier).set(false);
    }
  }

  static Future<void> _show(
    BuildContext context,
    ProviderContainer container,
    LibraryView view,
    DeskInviteStore store,
    DateTime now, {
    bool countIt = true,
  }) async {
    // Counted as shown before it opens, so a crash or a killed app can't
    // bring it straight back. A tester's on-demand showing doesn't count.
    if (countIt) await store.quietUntilDate(now.add(quiet));
    final pro = view.entitlement.isPro;
    final analytics = container.read(analyticsProvider)..logEvent('desk_invite_shown', {'plan': pro ? 'pro' : 'free'});
    if (!context.mounted) return;

    final choices = _DeskChoices(container.read(authStateProvider).value?.email ?? '');
    // Every way out — a button, the ✕, a swipe, a tap on the library —
    // ends here, so the checkbox counts however the sheet closes.
    await showEcSheet<void>(context, builder: (_) => _DeskInviteSheet(pro: pro, choices: choices));
    analytics.logEvent('desk_invite_${choices.action.name}');
    if (choices.neverAgain) {
      analytics.logEvent('desk_invite_never');
      await store.turnOff();
    }
    if (!context.mounted) return;
    final links = container.read(externalLinksProvider);
    switch (choices.action) {
      case _DeskAction.upgrade:
        await ProSheet.show(context, source: PlanSource.desk);
      case _DeskAction.preview:
        await links.openUrl(AppLinks.webApp);
      case _DeskAction.email:
        final opened = await links.composeEmail(
          choices.to,
          subject: 'LastReel on your computer',
          body: 'Open this on your computer and sign in with ${choices.to} — your projects are already there:\n\n'
              '${AppLinks.webApp}',
        );
        if (!opened && context.mounted) showEcToast(context, 'No email app found. Copy the link instead.');
      case _DeskAction.copy:
        await Clipboard.setData(ClipboardData(text: AppLinks.webApp.toString()));
        if (context.mounted) showEcToast(context, 'Link copied. Open it on your computer.');
      case _DeskAction.later:
        break;
    }
  }
}

/// The sheet itself: the eyebrow and ✕, a picture of the desk, the pitch,
/// the actions and "Don't show this again".
class _DeskInviteSheet extends StatefulWidget {
  final bool pro;
  final _DeskChoices choices;
  const _DeskInviteSheet({required this.pro, required this.choices});

  @override
  State<_DeskInviteSheet> createState() => _DeskInviteSheetState();
}

class _DeskInviteSheetState extends State<_DeskInviteSheet> {
  late final _email = TextEditingController(text: widget.choices.to);
  bool _editingEmail = false;

  _DeskChoices get _choices => widget.choices;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _pick(_DeskAction action) {
    _choices.action = action;
    Navigator.of(context).pop();
  }

  bool get _emailValid {
    final value = _email.text.trim();
    return value.contains('@') && !value.contains(' ') && value.indexOf('@') > 0 && !value.endsWith('@');
  }

  void _saveEmail() {
    if (!_emailValid) return;
    setState(() {
      _choices.to = _email.text.trim();
      _editingEmail = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final pro = widget.pro;
    Widget icon(IconData data, {double size = 16, Color? color}) => Icon(data, size: size, color: color ?? p.ink);

    return EcSheet(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                caps(pro ? 'Included with your Pro plan' : 'LastReel Pro · desktop & web'),
                style: t.eyebrow.copyWith(color: pro ? p.ok : p.accent),
              ),
            ),
            EcCircleButton.tint(
              icon: Icons.close_rounded,
              size: 44,
              tooltip: 'Close',
              onPressed: () => _pick(_DeskAction.later),
            ),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DeskPicture(pro: pro),
          const SizedBox(height: 18),
          EcHeadline(
            pro ? 'More room to work. ' : 'Finish your credits ',
            emphasis: pro ? 'Try the desk.' : 'on a big screen.',
            style: t.displayM.copyWith(fontSize: 34, height: 1),
          ),
          const SizedBox(height: 8),
          Text(
            pro
                ? 'Open LastReel in your computer’s browser. Your projects are already there.'
                : 'The desktop editor is part of Pro. Not sure yet? Preview it on the web first, '
                    'with the projects you already have.',
            style: t.body.copyWith(fontSize: 14, color: p.ink2, height: 1.5),
          ),
          if (pro) ...[
            const SizedBox(height: 14),
            if (_editingEmail)
              EcTextField(
                controller: _email,
                label: null,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _saveEmail(),
                suffix: EcButton.text(
                  label: 'Done',
                  size: EcButtonSize.small,
                  onPressed: _emailValid ? _saveEmail : null,
                ),
              )
            else
              _SendTo(email: _choices.to, onChange: () => setState(() => _editingEmail = true)),
          ],
          const SizedBox(height: 12),
          for (final (i, line) in [
            'Blocks, monitor and settings side by side',
            pro ? 'Paste a call sheet, Tab through rows' : 'Unlimited projects, every format, no ads',
          ].indexed) ...[
            if (i > 0) const SizedBox(height: 6),
            Text('✓ $line', style: t.body.copyWith(fontSize: 13, color: p.ink2)),
          ],
          const SizedBox(height: 18),
          if (pro) ...[
            EcButton(
              label: 'Email me the link',
              leading: icon(Icons.send_outlined, size: 17, color: p.onInk),
              onPressed: _choices.to.isEmpty ? null : () => _pick(_DeskAction.email),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: EcButton.secondary(
                    label: 'Copy link',
                    height: 50,
                    leading: icon(Icons.link_rounded),
                    onPressed: () => _pick(_DeskAction.copy),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: EcButton.secondary(label: 'Not now', height: 50, onPressed: () => _pick(_DeskAction.later)),
                ),
              ],
            ),
          ] else ...[
            EcButton(label: 'Upgrade to Pro', onPressed: () => _pick(_DeskAction.upgrade)),
            const SizedBox(height: 8),
            EcButton.secondary(
              label: 'Preview on the web',
              height: 50,
              trailing: icon(Icons.open_in_new_rounded, size: 15),
              onPressed: () => _pick(_DeskAction.preview),
            ),
            const SizedBox(height: 8),
            EcButton(
              label: 'Not now',
              variant: EcButtonVariant.plain,
              size: EcButtonSize.medium,
              expand: true,
              onPressed: () => _pick(_DeskAction.later),
            ),
          ],
          const SizedBox(height: 4),
          _NeverAgain(
            value: _choices.neverAgain,
            onChanged: (value) => setState(() => _choices.neverAgain = value),
          ),
        ],
      ),
    );
  }
}

/// 1.8b's "We'll send the link to" row: the signed-in address, and Change.
class _SendTo extends StatelessWidget {
  final String email;
  final VoidCallback onChange;
  const _SendTo({required this.email, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(14, 0, 4, 0),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Icon(Icons.mail_outline_rounded, size: 18, color: p.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('We’ll send the link to', style: t.fine.copyWith(color: p.muted)),
                Text(
                  email.isEmpty ? 'Add your email' : email,
                  style: t.titleS.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          EcButton.text(label: 'Change', size: EcButtonSize.medium, onPressed: onChange),
        ],
      ),
    );
  }
}

/// "Don't show this again": a checkbox, so it applies however the sheet is
/// closed afterwards.
class _NeverAgain extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NeverAgain({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 18,
                child: Checkbox(
                  value: value,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: p.accentSolid,
                  side: BorderSide(color: p.line2, width: 1.5),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 10),
              Text('Don’t show this again', style: t.body.copyWith(fontSize: 13, color: p.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The web app in miniature: blocks, a monitor with a credit and its
/// timeline, settings — with a PRO tag on Free.
class _DeskPicture extends StatelessWidget {
  final bool pro;
  const _DeskPicture({required this.pro});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    Widget bar(Color color, {double height = 6, double? width}) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        );
    Widget gapped(List<Widget> children, double gap) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, child) in children.indexed) ...[if (i > 0) SizedBox(height: gap), child],
          ],
        );
    Widget segment(int flex, Color color) => Expanded(
          flex: flex,
          child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        );
    final credit = GoogleFonts.archivoNarrow(color: Colors.white);

    return ExcludeSemantics(
      child: Container(
        height: 116,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFFECE6DC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.line),
          boxShadow: const [
            BoxShadow(color: Color(0x803C2814), offset: Offset(0, 20), blurRadius: 40, spreadRadius: -26),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Row(
                  children: [
                    for (final (i, c) in const [Color(0xFFFF5F57), Color(0xFFFEBC2E), Color(0xFF28C840)].indexed)
                      Container(
                        width: 7,
                        height: 7,
                        margin: EdgeInsets.only(left: i == 0 ? 0 : 5),
                        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                      ),
                    Expanded(
                      child: Container(
                        height: 10,
                        margin: const EdgeInsets.only(left: 35, right: 52),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .75),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 62,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: gapped([bar(p.line2), bar(p.accentSolid), bar(p.line2), bar(p.line2)], 4),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('CAST', style: credit.copyWith(fontSize: 5, letterSpacing: 1.5, color: Colors.white54)),
                                    const SizedBox(height: 3),
                                    Text(
                                      'SOFIA ALVAREZ',
                                      style: credit.copyWith(fontSize: 7.5, fontWeight: FontWeight.w600, letterSpacing: .9),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              height: 14,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .7),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                children: [
                                  segment(1, p.line2),
                                  const SizedBox(width: 2),
                                  segment(5, p.accentSolid),
                                  const SizedBox(width: 2),
                                  segment(4, p.line2),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 78,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FractionallySizedBox(widthFactor: .6, child: bar(p.ink, height: 9)),
                            const SizedBox(height: 4),
                            bar(p.tint, height: 9, width: double.infinity),
                            const SizedBox(height: 4),
                            bar(p.tint, height: 9, width: double.infinity),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!pro)
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: p.primary,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: p.primaryShadow,
                  ),
                  child: Text(
                    'PRO',
                    style: t.mono.copyWith(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: p.onInk),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
