import 'dart:async';
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
  throw StateError(
    'trackingStoreProvider was not overridden — see bootstrap().',
  );
});

/// Set once the pre-prompt has had its chance this run of the app, so the
/// desk invite and the rating prompt stay out of the same session.
final trackingPromptThisSessionProvider =
    NotifierProvider<ShownThisSession, bool>(ShownThisSession.new);

/// A short
/// explainer before iOS's own App Tracking Transparency alert.
///
/// When it shows: on the first Home visit on Free iOS while ATT is undecided. It comes up over the
/// library, never mid-edit, never with the desk invite or the rating prompt
/// in the same session. If iOS has already decided (Settings, a managed
/// device), it never shows. Pro is never asked: Pro sees no ads.
///
/// One action, Continue, which hands over to iOS. No close and no "Not
/// now": iOS itself offers the no.
abstract final class TrackingPrompt {
  static final _busy = Provider((ref) => _PromptBusy());

  static bool due({
    required TrackingStore store,
    required DateTime now,
    required bool ios,
    required bool free,
    required bool web,
  }) {
    if (!ios || web || !free) return false;
    final first = store.firstSeen;
    return first != null;
  }

  /// Called from the library's build: only while the library itself is on
  /// top, and after the frame, since providers can't change mid-build.
  static void check(BuildContext context, LibraryView? view) {
    if (view == null) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
        maybeShow(context);
      }
    });
  }

  static Future<void> maybeShow(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final web = kIsWeb || container.read(runningOnWebProvider) || container.read(verifiedWorkspaceProvider);
    if (!ios || web || container.read(_busy).active) return;
    // The plan reads as Free until the store answers: wait for it, or Pro
    // would be asked about ads it never sees.
    final entitlement = container.read(entitlementProvider);
    if (!entitlement.hasValue || entitlement.isLoading) return;
    final store = container.read(trackingStoreProvider);
    final now = container.read(clockProvider)();
    if (container.read(deskInviteOpenProvider) ||
        container.read(deskInviteShownThisSessionProvider) ||
        container.read(reviewPromptShownThisSessionProvider) ||
        !due(
          store: store,
          now: now,
          ios: ios,
          free: entitlement.requireValue.showsAds,
          web: web,
        )) {
      return;
    }
    final busy = container.read(_busy);
    final gate = container.read(trackingConsentGateProvider);
    busy.active = true;
    container.read(trackingPromptThisSessionProvider.notifier).mark();
    try {
      await waitForActiveApp();
      if (!context.mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      // Claimed before anything is awaited, so the desk invite, checking
      // after the same frame, keeps out of this session.
      final authorization = container.read(trackingAuthorizationProvider);
      final status = await authorization.status();
      if (status != TrackingAuthorizationStatus.notDetermined) {
        gate.resolve(status);
        // Decided in iOS already: respect it and never ask.
        await store.markPrePromptDone();
        return;
      }
      // The system status is authoritative, including upgrades from old builds.
      final analytics = container.read(analyticsProvider)
        ..logEvent('att_preprompt_shown', {'source': 'first_home'});
      if (!context.mounted) return;
      await show(context);
      analytics.logEvent('att_preprompt_continue');
      await waitForActiveApp();
      if (!context.mounted) return;
      final result = await authorization.request();
      gate.resolve(result);
      if (result != TrackingAuthorizationStatus.notDetermined) {
        await store.markPrePromptDone();
      }
      if (context.mounted) {
        analytics.logEvent('att_result', {'status': result.name});
        container.invalidate(trackingStatusProvider);
      }
    } finally {
      busy.active = false;
    }
  }

  /// The pre-prompt alone: a sheet on a phone, a centred 560-wide card on
  /// a tablet. Completes when Continue is tapped.
  static Future<void> show(BuildContext context) {
    final tablet = context.tabletLayout;
    if (tablet == null) {
      final route = ModalBottomSheetRoute<void>(
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        modalBarrierColor: context.palette.scrim,
        builder: (_) => const _PrePromptSheet(),
      );
      unawaited(Navigator.of(context).push(route));
      return route.completed.then((_) {});
    }
    final route = DialogRoute<void>(
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
            child: const _PrePromptCard(),
          ),
        ),
      ),
    );
    unawaited(Navigator.of(context).push(route));
    return route.completed.then((_) {});
  }
}

class _PromptBusy {
  bool active = false;
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
                    decoration: BoxDecoration(
                      color: p.line2,
                      borderRadius: BorderRadius.circular(2),
                    ),
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

/// A centred permission explanation on tablets.
class _PrePromptCard extends StatelessWidget {
  const _PrePromptCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.sheet,
        borderRadius: BorderRadius.circular(28),
        boxShadow: EcDialog.shadow,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
              child: const _PrePromptContent(titleSize: 34),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrePromptContent extends StatelessWidget {
  final double titleSize;
  const _PrePromptContent({required this.titleSize});

  static const _promises = [
    (
      Icons.drag_handle_rounded,
      'The same number of ads either way',
      'Saying no never adds ads or locks anything.',
    ),
    (
      Icons.lock_outline_rounded,
      'Your projects stay yours',
      'Names and credits you type are never used for ads.',
    ),
    (
      Icons.tune_rounded,
      'Change it anytime',
      'iOS Settings › Privacy & Security › Tracking.',
    ),
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
            'About ad ',
            emphasis: 'privacy.',
            style: t.displayL.copyWith(fontSize: titleSize, height: 1.05),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'LastReel uses advertising partners to show ads. Next, iOS will ask whether you allow tracking '
          'across other companies’ apps and websites to personalize advertising. Your choice won’t '
          'change access to the app or the number of ads.',
          style: t.body.copyWith(fontSize: 14, height: 1.5, color: p.ink2),
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
                        decoration: BoxDecoration(
                          color: p.accentWash,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, size: 16, color: p.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: t.titleS.copyWith(fontSize: 13.5),
                            ),
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
