import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/features.dart';
import '../../../core/widgets/ec_button.dart';
import '../controllers/auth_controller.dart';
import 'google_mark.dart';

/// "Continue with Apple" and "Continue with Google".
///
/// [compact] allows a side-by-side pair when the full provider labels fit.
/// Apple is black and Google white, with equal prominence. Phones stack
/// the native Apple/Google pair so neither title needs to be abbreviated.
class SocialSignInButtons extends ConsumerWidget {
  final bool compact;

  /// The tablet's sign-in (T0.1, P0.1): "Continue with …" in full and 52
  /// tall, side by side when [compact].
  final bool tablet;

  const SocialSignInButtons({
    super.key,
    this.compact = false,
    this.tablet = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final idle = !form.busy;

    final appleAvailable = Features.appleSignIn;
    final short = compact && !tablet && !appleAvailable;
    final height = tablet ? 52.0 : null;
    final apple = EcButton(
      label: 'Continue with Apple',
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

    if (!appleAvailable) return google;
    // The tablet leads with Google (T0.1); the phone with Apple.
    final pair = tablet ? [google, apple] : [apple, google];
    Widget stacked() => Column(
      mainAxisSize: MainAxisSize.min,
      children: [pair[0], const SizedBox(height: 10), pair[1]],
    );
    // The sign-in scaffold measures intrinsic height, so use its known
    // tablet layout and viewport instead of a nested LayoutBuilder.
    final scale = MediaQuery.textScalerOf(context).scale(15) / 15;
    if (!compact || !tablet || MediaQuery.sizeOf(context).width < 620 * scale) {
      return stacked();
    }
    return Row(
      children: [
        Expanded(child: pair[0]),
        const SizedBox(width: 10),
        Expanded(child: pair[1]),
      ],
    );
  }
}
