import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/theme/tokens.dart';
import '../../library/screens/library_screen.dart';
import '../../onboarding/screens/welcome_screen.dart';

/// Chooses between the onboarding/auth flow and the app, driven by the auth
/// stream rather than by navigation — a sign-out from anywhere, or an
/// expired session, swaps the tree here without any screen having to
/// remember to route.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return switch (auth) {
      // The first event is the restored session, so this is the brief
      // moment before Firebase has answered — not a signed-out state.
      AsyncLoading() => const _Splash(),
      AsyncError(:final error) => _Splash(message: 'Could not reach sign-in.\n$error'),
      AsyncValue(:final value) => value == null ? const _AuthFlow() : const LibraryScreen(),
    };
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
class _AuthFlow extends StatefulWidget {
  const _AuthFlow();

  @override
  State<_AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<_AuthFlow> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      onPopWithResult: (_) => _navigator.currentState?.maybePop(),
      child: Navigator(
        key: _navigator,
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
      backgroundColor: EcColors.surfaceCanvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ENDCRAWL',
              style: TextStyle(
                fontFamily: EcFonts.archivoNarrow,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: 5.5,
                color: EcColors.textPrimary,
              ),
            ),
            const SizedBox(height: EcSpace.s5),
            if (message == null)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: EcColors.accentPrimary),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: EcSpace.s6),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, height: 1.4, color: EcColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
