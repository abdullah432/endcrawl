import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap.dart';
import '../../core/config/app_links.dart';
import '../../core/theme/ec_type.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/ec_button.dart';
import '../../core/widgets/ec_headline.dart';
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

/// Set as the invite opens, so it comes up at most once per run of the app.
final deskInviteShownThisSessionProvider = NotifierProvider<ShownThisSession, bool>(ShownThisSession.new);

/// True from the moment the invite opens until its follow-up (the Pro
/// sheet, the mail app) is done.
final deskInviteOpenProvider = NotifierProvider<DeskInviteOpen, bool>(DeskInviteOpen.new);

class DeskInviteOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool open) => state = open;
}

enum _DeskChoice { upgrade, email, copy, later, never }

/// 1.8a / 1.8b — "LastReel on a big screen", raised on the library.
///
/// Free (1.8a) sells the upgrade, since the desk editor is part of Pro; Pro
/// (1.8b) gets the web app's link to a computer, by their own email app or
/// the clipboard. It shows once the library is full — two of two projects
/// on Free, three or more on Pro — never on the web (that is the desk),
/// never in the same session as the rating prompt, at most once every 30
/// days, and never again after "Don't show this again".
///
/// A tester on iOS (see `testerAllowedProvider`) skips the 30-day quiet,
/// the off switch and the rating clash, and gets it again every time they
/// come back to the library — so it can be shown and checked on demand.
abstract final class DeskInvite {
  static const quiet = Duration(days: 30);
  static const proThreshold = 3;

  static bool due({
    required LibraryView view,
    required DeskInviteStore store,
    required DateTime now,
    required bool ratedThisSession,
    required bool web,
    bool tester = false,
  }) {
    if (web) return false;
    if (!tester) {
      if (store.turnedOff || ratedThisSession) return false;
      final until = store.quietUntil;
      if (until != null && now.isBefore(until)) return false;
    }
    return view.entitlement.isPro ? view.count >= proThreshold : view.isFull;
  }

  /// Called from the library's build: only while the library itself is on
  /// top (never over the editor or an export), and after the frame, since
  /// providers can't change mid-build.
  static bool _tester(ProviderContainer container) =>
      !container.read(runningOnWebProvider) &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      (container.read(testerAllowedProvider).value ?? false);

  static void check(BuildContext context, LibraryView? view) {
    if (view == null) return;
    final route = ModalRoute.of(context);
    if (!(route?.isCurrent ?? true)) {
      _rearmForTester(context, route!);
      return;
    }
    _checkSoon(context);
  }

  static void _checkSoon(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? true)) maybeShow(context);
    });
  }

  /// A tester gets the invite again each time they come back to the
  /// library from another page (the editor, Settings). A page on top moves
  /// the library's secondary animation; a sheet — the invite itself
  /// included — doesn't, so closing one never brings the invite back.
  static void _rearmForTester(BuildContext context, ModalRoute<Object?> route) {
    final covered = route.secondaryAnimation;
    if (covered == null || covered.status == AnimationStatus.dismissed) return;
    final container = ProviderScope.containerOf(context, listen: false);
    if (!_tester(container)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!container.read(deskInviteShownThisSessionProvider) || container.read(deskInviteOpenProvider)) return;
      container.read(deskInviteShownThisSessionProvider.notifier).reset();
      void back(AnimationStatus status) {
        if (status != AnimationStatus.dismissed) return;
        covered.removeStatusListener(back);
        if (context.mounted) _checkSoon(context);
      }

      covered.addStatusListener(back);
    });
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
    final tester = _tester(container);
    if (container.read(deskInviteShownThisSessionProvider) ||
        container.read(deskInviteOpenProvider) ||
        !due(
          view: view,
          store: store,
          now: now,
          ratedThisSession: container.read(reviewPromptShownThisSessionProvider),
          web: container.read(runningOnWebProvider),
          tester: tester,
        )) {
      return;
    }
    container.read(deskInviteShownThisSessionProvider.notifier).mark();
    container.read(deskInviteOpenProvider.notifier).set(true);
    try {
      await _show(context, container, view, store, now, tester: tester);
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
    required bool tester,
  }) async {
    // Counted as shown before it opens, so a crash or a killed app can't
    // bring it straight back. A tester's showings don't count.
    if (!tester) await store.quietUntilDate(now.add(quiet));
    final pro = view.entitlement.isPro;
    final analytics = container.read(analyticsProvider)..logEvent('desk_invite_shown', {'plan': pro ? 'pro' : 'free'});
    if (!context.mounted) return;

    final choice = await showEcSheet<_DeskChoice>(context, builder: (_) => DeskInviteSheet(pro: pro));
    analytics.logEvent('desk_invite_${(choice ?? _DeskChoice.later).name}');
    if (!context.mounted) return;
    switch (choice) {
      case _DeskChoice.upgrade:
        await ProSheet.show(context, source: PlanSource.desk);
      case _DeskChoice.email:
        final email = container.read(authStateProvider).value?.email ?? '';
        final opened = await container.read(externalLinksProvider).composeEmail(
              email,
              subject: 'LastReel on your computer',
              body: 'Open this on your computer and sign in with $email — your projects are already there:\n\n'
                  '${AppLinks.webApp}',
            );
        if (!opened && context.mounted) showEcToast(context, 'No email app found. Copy the link instead.');
      case _DeskChoice.copy:
        await Clipboard.setData(ClipboardData(text: AppLinks.webApp.toString()));
        if (context.mounted) showEcToast(context, 'Link copied. Open it on your computer.');
      case _DeskChoice.never:
        await store.turnOff();
      case _DeskChoice.later || null:
        break;
    }
  }
}

/// The sheet itself: a picture of the desk, the pitch, and the actions.
class DeskInviteSheet extends StatelessWidget {
  final bool pro;
  const DeskInviteSheet({super.key, required this.pro});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    void pick(_DeskChoice choice) => Navigator.of(context).pop(choice);
    Widget tick(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('✓ $text', style: t.body.copyWith(color: p.ink2)),
        );

    return EcSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DeskPicture(pro: pro),
          const SizedBox(height: 22),
          Text(
            caps(pro ? 'Included with your Pro plan' : 'LastReel Pro · desktop & web'),
            style: t.eyebrow.copyWith(color: pro ? p.ok : p.accent),
          ),
          const SizedBox(height: 8),
          EcHeadline(
            pro ? 'More room to work. ' : 'Finish your credits ',
            emphasis: pro ? 'Try the desk.' : 'on a big screen.',
            style: t.displayM.copyWith(fontSize: 34),
          ),
          const SizedBox(height: 12),
          Text(
            pro
                ? 'We’ll email you a link. Open it on your computer and your projects are already there.'
                : 'The desktop editor is part of Pro. Upgrade to edit, time and export from any computer, '
                    'with the projects you already have.',
            style: t.body.copyWith(color: p.ink2, height: 1.45),
          ),
          const SizedBox(height: 14),
          tick('Blocks, monitor and settings side by side'),
          tick(pro ? 'Paste a call sheet, Tab through rows' : 'Unlimited projects, every format, no ads'),
          const SizedBox(height: 22),
          if (pro) ...[
            EcButton(label: 'Email me the link', onPressed: () => pick(_DeskChoice.email)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: EcButton.secondary(label: 'Copy link', onPressed: () => pick(_DeskChoice.copy))),
                const SizedBox(width: 10),
                Expanded(child: EcButton.secondary(label: 'Not now', onPressed: () => pick(_DeskChoice.later))),
              ],
            ),
          ] else ...[
            EcButton(label: 'Upgrade to Pro', onPressed: () => pick(_DeskChoice.upgrade)),
            const SizedBox(height: 10),
            EcButton.secondary(label: 'Not now', onPressed: () => pick(_DeskChoice.later)),
          ],
          const SizedBox(height: 6),
          EcButton(
            label: 'Don’t show this again',
            variant: EcButtonVariant.plain,
            expand: true,
            onPressed: () => pick(_DeskChoice.never),
          ),
        ],
      ),
    );
  }
}

/// The web app in miniature: blocks, a monitor with a credit, settings,
/// and a timeline — with a PRO tag on Free.
class _DeskPicture extends StatelessWidget {
  final bool pro;
  const _DeskPicture({required this.pro});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    Widget bar(double w, {bool accent = false}) => Container(
          height: 6,
          width: w,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: accent ? p.accentSolid : p.line2,
            borderRadius: BorderRadius.circular(3),
          ),
        );
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: 2.2,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFECE6DC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.line),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Row(
                    children: [
                      for (final c in const [Color(0xFFFF5F57), Color(0xFFFEBC2E), Color(0xFF28C840)])
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(8)),
                            child: Column(children: [bar(60), bar(60), bar(60, accent: true), bar(60)]),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(8),
                                    border: pro ? Border.all(color: p.accentSolid, width: 1.5) : null,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('CAST', style: t.mono.copyWith(fontSize: 6, color: Colors.white54, letterSpacing: 2)),
                                      const SizedBox(height: 3),
                                      Text(
                                        'SOFIA ALVAREZ',
                                        style: t.mono.copyWith(fontSize: 8.5, color: Colors.white, letterSpacing: 1.2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Expanded(child: bar(double.infinity)),
                                  const SizedBox(width: 3),
                                  Expanded(flex: 3, child: bar(double.infinity, accent: true)),
                                  const SizedBox(width: 3),
                                  Expanded(flex: 2, child: bar(double.infinity)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!pro)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(gradient: p.primary, borderRadius: BorderRadius.circular(999)),
                    child: Text('PRO', style: t.pill.copyWith(color: p.onInk, letterSpacing: 1.4)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
