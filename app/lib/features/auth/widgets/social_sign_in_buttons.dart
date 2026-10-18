import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/features.dart';
import '../../../core/widgets/ec_button.dart';
import '../controllers/auth_controller.dart';
import 'google_mark.dart';

/// "Continue with Apple" and "Continue with Google".
///
/// [compact] is the side-by-side pair under "or" on 0.2 ("Apple", "Google");
/// otherwise they stack full-width, as on the welcome screen. Apple is
/// black and Google white, per each company's button guidelines. Apple
/// shows only when [Features.appleSignIn] is on; Google then stands alone.
class SocialSignInButtons extends ConsumerWidget {
  final bool compact;

  /// The tablet's sign-in (T0.1, P0.1): "Continue with …" in full and 52
  /// tall, side by side when [compact].
  final bool tablet;

  const SocialSignInButtons({super.key, this.compact = false, this.tablet = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final idle = !form.busy;

    final short = compact && !tablet;
    final height = tablet ? 52.0 : null;
    final apple = EcButton(
      label: short ? 'Apple' : 'Continue with Apple',
      variant: EcButtonVariant.black,
      size: short ? EcButtonSize.medium : EcButtonSize.large,
      height: height,
      expand: true,
      busy: form.isRunning(AuthAction.apple),
      leading: const Icon(Icons.apple, size: 20, color: Colors.white),
      onPressed: idle ? controller.signInWithApple : null,
    );
    final google = EcButton.secondary(
      label: short ? 'Google' : 'Continue with Google',
      size: short ? EcButtonSize.medium : EcButtonSize.large,
      height: height,
      expand: true,
      busy: form.isRunning(AuthAction.google),
      leading: const GoogleMark(),
      onPressed: idle ? controller.signInWithGoogle : null,
    );

    if (!Features.appleSignIn) return google;
    // The tablet leads with Google (T0.1); the phone with Apple.
    final pair = tablet ? [google, apple] : [apple, google];
    if (compact) {
      return Row(children: [Expanded(child: pair[0]), const SizedBox(width: 10), Expanded(child: pair[1])]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [pair[0], const SizedBox(height: 10), pair[1]]);
  }
}
