import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/ec_button.dart';
import '../../core/widgets/ec_dialog.dart';
import '../../core/widgets/ec_headline.dart';
import '../../core/widgets/ec_surfaces.dart';
import '../access/controllers/web_access.dart';
import '../desk/desk_invite.dart';
import '../home/tablet_layout.dart';
import '../library/controllers/library_controller.dart';
import '../review/review_prompt.dart';
import 'tracking_authorization.dart';
import 'tracking_store.dart';

/// Overridden in `main` with the SharedPreferences-backed store, and in
/// tests with an in-memory one.
final trackingStoreProvider = Provider<TrackingStore>((ref) {
  throw StateError('trackingStoreProvider was not overridden — see bootstrap().');
});

/// Set once the pre-prompt has had its chance this run of the app, so the
/// desk invite and the rating prompt stay out of the same session.
final trackingPromptThisSessionProvider = NotifierProvider<ShownThisSession, bool>(ShownThisSession.new);

/// A1 / A4 / A5 — "Keep LastReel free, with ads that fit.": a short
/// explainer before iOS's own App Tracking Transparency alert.
///
/// When it shows: once, on Free, on iOS, when the app is opened at least
/// [settleIn] after it was first opened on this device — so people have
/// used LastReel and liked it before they are asked. It comes up over the
/// library, never mid-edit, never with the desk invite or the rating prompt
/// in the same session. If iOS has already decided (Settings, a managed
/// device), it never shows. Pro is never asked: Pro sees no ads.
///
/// One action, Continue, which hands over to iOS. No close and no "Not
/// now": iOS itself offers the no.
abstract final class TrackingPrompt {
  static const settleIn = Duration(days: 3);

  static bool due({
    required TrackingStore store,
    required DateTime now,
    required bool ios,
    required bool free,
    required bool web,
  }) {
    if (!ios || web || !free || store.prePromptDone) return false;
    final first = store.firstSeen;
    return first != null && !now.isBefore(first.add(settleIn));
  }

  /// Called from the library's build: only while the library itself is on
  /// top, and after the frame, since providers can't change mid-build.
  static void check(BuildContext context, LibraryView? view) {
    if (view == null) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? true)) maybeShow(context);
    });
  }

  static Future<void> maybeShow(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final web = container.read(verifiedWorkspaceProvider);
    if (!ios || web || container.read(trackingPromptThisSessionProvider)) return;
    // The plan reads as Free until the store answers: wait for it, or Pro
    // would be asked about ads it never sees.
    final entitlement = container.read(entitlementProvider);
    if (!entitlement.hasValue || entitlement.isLoading) return;
    final store = container.read(trackingStoreProvider);
    final now = container.read(clockProvider)();
    if (container.read(deskInviteOpenProvider) ||
        container.read(deskInviteShownThisSessionProvider) ||
        container.read(reviewPromptShownThisSessionProvider) ||
        !due(store: store, now: now, ios: ios, free: entitlement.requireValue.showsAds, web: web)) {
      return;
    }
    // Claimed before anything is awaited, so the desk invite, checking
    // after the same frame, keeps out of this session.
    container.read(trackingPromptThisSessionProvider.notifier).mark();
    final authorization = container.read(trackingAuthorizationProvider);
    if (await authorization.status() != TrackingAuthorizationStatus.notDetermined) {
      // Decided in iOS already: respect it and never ask.
      await store.markPrePromptDone();
      return;
    }
    // Counted before it opens, so a killed app can't bring it back.
    await store.markPrePromptDone();
    final analytics = container.read(analyticsProvider)
      ..logEvent('att_preprompt_shown', {'source': 'day_${settleIn.inDays}_open'});
    if (!context.mounted) return;
    await show(context);
    analytics.logEvent('att_preprompt_continue');
    final result = await authorization.request();
    analytics.logEvent('att_result', {'status': result.name});
    container.invalidate(trackingStatusProvider);
  }

  /// The pre-prompt alone: a sheet on a phone, a centred 560-wide card on
  /// a tablet. Completes when Continue is tapped.
  static Future<void> show(BuildContext context) {
    final tablet = context.tabletLayout;
    if (tablet == null) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: context.palette.scrim,
        builder: (_) => const _PrePromptSheet(),
      );
    }
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: context.palette.scrim,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _PrePromptCard(art: tablet == TabletLayout.portrait),
          ),
        ),
      ),
    );
  }
}

/// A1 — the phone's sheet.
class _PrePromptSheet extends StatelessWidget {
  const _PrePromptSheet();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopScope(
      canPop: false,
      child: Container(
        decoration: BoxDecoration(
          color: p.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: p.line2, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                const _PrePromptContent(titleSize: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A4 / A5 — the tablet's card; [art] adds the panel on top in portrait.
class _PrePromptCard extends StatelessWidget {
  final bool art;
  const _PrePromptCard({required this.art});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: p.sheet, borderRadius: BorderRadius.circular(28), boxShadow: EcDialog.shadow),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (art) const _Art(),
            Padding(
              padding: EdgeInsets.fromLTRB(14, art ? 18 : 12, 14, 6),
              child: const _PrePromptContent(titleSize: 34),
            ),
          ],
        ),
      ),
    );
  }
}

/// A5's art: LastReel Free, made possible by a few quiet ads.
class _Art extends StatelessWidget {
  const _Art();

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Container(
      height: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black, Color(0xFF0B0B12), Color(0xFF2A2350)],
          stops: [0, .6, 1],
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Stack(
        children: [
          Text('LastReel Free', style: t.mono.copyWith(fontSize: 10, color: Colors.white.withValues(alpha: .6))),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MADE POSSIBLE BY',
                  style: t.eyebrow.copyWith(
                    fontSize: 9,
                    letterSpacing: 2.4,
                    color: Colors.white.withValues(alpha: .55),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A FEW QUIET ADS',
                  style: t.titleM.copyWith(
                    fontSize: 16,
                    letterSpacing: 3.2,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrePromptContent extends StatelessWidget {
  final double titleSize;
  const _PrePromptContent({required this.titleSize});

  static const _promises = [
    (Icons.drag_handle_rounded, 'The same number of ads either way', 'Saying no never adds ads or locks anything.'),
    (Icons.lock_outline_rounded, 'Your projects stay yours', 'Names and credits you type are never used for ads.'),
    (Icons.tune_rounded, 'Change it anytime', 'iOS Settings › Privacy & Security › Tracking.'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EcEyebrow('Before iOS asks'),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: EcHeadline(
            'Keep LastReel free,',
            emphasis: 'with ads that fit.',
            style: t.displayL.copyWith(fontSize: titleSize, height: 1.05),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'LastReel is free because of a few quiet ads. Next, iOS asks if apps may use your activity to choose '
          'them. Say yes and they’re more likely to be about film than random things.',
          style: t.body.copyWith(fontSize: 14, height: 1.5, color: p.ink2),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final topic in const ['Cameras & lenses', 'Editing tools', 'Film festivals'])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: p.line),
                ),
                child: Text(topic, style: t.bodyS.copyWith(fontSize: 12, color: p.ink2)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.line),
          ),
          child: Column(
            children: [
              for (final (icon, title, body) in _promises)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: p.accentWash, borderRadius: BorderRadius.circular(8)),
                        child: Icon(icon, size: 16, color: p.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: t.titleS.copyWith(fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text(body, style: t.caption.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        EcButton(
          label: 'Continue',
          variant: EcButtonVariant.ink,
          size: EcButtonSize.large,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 10),
        Text(
          'iOS shows its own choice next: Allow, or Ask App Not to Track.',
          textAlign: TextAlign.center,
          style: t.caption.copyWith(fontSize: 11.5),
        ),
      ],
    );
  }
}
