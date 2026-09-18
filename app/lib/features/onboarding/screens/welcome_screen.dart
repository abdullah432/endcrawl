import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/screens/email_sign_in_screen.dart';
import '../../auth/widgets/auth_navigation.dart';
import '../../auth/widgets/auth_scaffold.dart';
import '../../auth/widgets/google_mark.dart';
import '../widgets/roll_hero.dart';

/// The first screen anyone sees, and the whole of onboarding.
///
/// There is no feature carousel on purpose. The product's promise is a
/// broadcast-clean credit roll in under a minute; making someone swipe
/// through three cards before they can start would undercut exactly the
/// thing being sold. The roll behind this screen does the explaining, and
/// the two buttons are the only decision on offer.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcColors.surfaceCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RollHero(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: EcSpace.s5),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  // The panel's spacers push the buttons to the bottom on a
                  // normal phone; the scroll view and minHeight keep the
                  // screen usable in landscape or at a large text scale,
                  // where the content is taller than the window and would
                  // otherwise simply overflow.
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: const IntrinsicHeight(child: _WelcomePanel()),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePanel extends ConsumerWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const _Wordmark(),
        const SizedBox(height: EcSpace.s4),
        const Text(
          'End credits that roll clean.\nPick a runtime — the motion follows.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5, color: EcColors.textSecondary),
        ),
        const Spacer(),
        if (form.failure != null) ...[
          AuthBanner(message: form.failure!.message),
          const SizedBox(height: EcSpace.s4),
        ],
        _GoogleButton(busy: form.busy, onPressed: controller.signInWithGoogle),
        const SizedBox(height: EcSpace.s3),
        OutlinedButton(
          onPressed: form.busy
              ? null
              : () => pushAuthScreen(context, ref, const EmailSignInScreen()),
          style: OutlinedButton.styleFrom(
            foregroundColor: EcColors.textPrimary,
            disabledForegroundColor: EcColors.textDisabled,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: EcColors.borderStrong),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Continue with email'),
          ),
        ),
        const SizedBox(height: EcSpace.s6),
        const Text(
          'Your projects sync to your account, so a dead\nbattery is never a lost cut.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, height: 1.5, color: EcColors.textTertiary),
        ),
        const SizedBox(height: EcSpace.s5),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The wordmark is one unbreakable word with wide tracking, so on a
        // narrow phone it has to shrink rather than clip.
        const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'ENDCRAWL',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: EcFonts.archivoNarrow,
              fontWeight: FontWeight.w700,
              fontSize: 34,
              letterSpacing: 9,
              color: EcColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: EcSpace.s3),
        Container(width: 46, height: 2, color: EcColors.accentPrimary),
      ],
    );
  }
}

/// Google's button, in Google's colours.
///
/// White rather than the app's gold accent: it is what Google's branding
/// guidelines call for, and it happens to give the right hierarchy anyway —
/// this is the path most people will take, so it should be the brightest
/// thing on the screen.
class _GoogleButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;

  const _GoogleButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F1F1F),
        disabledBackgroundColor: const Color(0xFF6E7176),
        disabledForegroundColor: const Color(0xFF2B2D30),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2B2D30)),
            )
          // Scales down rather than clipping: the mark plus the label is
          // wider than a narrow phone at a large text scale.
          : const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GoogleMark(),
                  SizedBox(width: EcSpace.s3),
                  Text('Continue with Google'),
                ],
              ),
            ),
    );
  }
}
