import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/ec_toast.dart';
import '../../../bootstrap.dart';
import '../../../core/config/features.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_logo.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../access/controllers/web_access.dart';
import '../../access/screens/web_access_screen.dart';
import '../../library/screens/library_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';
import '../controllers/auth_controller.dart';
import '../screens/verify_email_screen.dart';

/// Chooses between the onboarding/auth flow and the app, driven by the auth
/// stream rather than by navigation — a sign-out from anywhere, or an
/// expired session, swaps the tree here without any screen having to
/// remember to route.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    // The gate swaps what's at the root, but screens pushed on top of it
    // (Settings, the editor) belong to the account that pushed them. When
    // that account signs out, is deleted or is replaced, clear them, or the
    // welcome screen would appear *underneath* a stale Settings screen.
    ref.listen(currentUidProvider, (previous, next) {
      if (previous != null && previous != next) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    return switch (auth) {
      // The first event is the restored session, so this is the brief
      // moment before Firebase has answered — not a signed-out state.
      AsyncLoading() => const _Splash(),
      AsyncError(:final error) => _Splash(message: 'Could not reach sign-in.\n$error'),
      AsyncValue(:final value) => switch (value) {
          null => const _AuthFlow(),
          final user when Features.emailVerification && user.needsEmailVerification => VerifyEmailScreen(user: user),
          _ when ref.watch(runningOnWebProvider) => const _WebHome(),
          _ => const LibraryScreen(),
        },
    };
  }
}

/// Signed in on the web: Pro accounts go straight to their projects; a
/// free account lands on the access page (D2) until it chooses to preview.
/// After a successful check the access page stays up to say so (D6) until
/// "Open my projects".
class _WebHome extends ConsumerWidget {
  const _WebHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(entitlementProvider);
    if (!plan.hasValue) return const _Splash();
    final entered = ref.watch(webEntryProvider);
    final justUnlocked = ref.watch(accessCheckProvider.select((c) => c.phase == AccessPhase.unlocked));
    final pro = plan.value!.isPro;
    if (!entered && (!pro || justUnlocked)) return const WebAccessScreen();
    return const LibraryScreen();
  }
}

/// The signed-out branch, hosted in its own [Navigator].
///
/// This matters: the auth screens push onto *this* navigator, not the root
/// one. Signing in from a pushed screen removes this whole subtree, taking
/// its route stack with it — on the root navigator the library would appear
/// underneath a create-account screen that never got popped.
///
/// [NavigatorPopHandler] forwards the system back gesture down here first,
/// so Android back walks the auth screens before it tries to leave the app.
class _AuthFlow extends ConsumerStatefulWidget {
  const _AuthFlow();

  @override
  ConsumerState<_AuthFlow> createState() => _AuthFlowState();
}

/// Clears the shared form state whenever an auth screen is popped — by the
/// back button, the swipe-back gesture or Android back alike — so the screen
/// underneath never shows a failure raised on the one above it.
class _ClearMessagesOnPop extends NavigatorObserver {
  final VoidCallback onPop;
  _ClearMessagesOnPop(this.onPop);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Deferred: pops can land mid-frame, and Riverpod forbids writing to a
    // provider while the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) => onPop());
  }
}

class _AuthFlowState extends ConsumerState<_AuthFlow> {
  final _navigator = GlobalKey<NavigatorState>();
  late final _clearOnPop = _ClearMessagesOnPop(() {
    if (mounted) ref.read(authControllerProvider.notifier).clearMessages();
  });

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      onPopWithResult: (_) => _navigator.currentState?.maybePop(),
      child: Navigator(
        key: _navigator,
        observers: [_clearOnPop, EcToastObserver()],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const WelcomeScreen(),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  final String? message;
  const _Splash({this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EcGround(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EcLogo(size: 18),
              const SizedBox(height: 20),
              if (message == null)
                const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(message!, textAlign: TextAlign.center, style: context.type.body),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
