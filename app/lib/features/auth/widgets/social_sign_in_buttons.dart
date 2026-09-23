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

  const SocialSignInButtons({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final idle = !form.busy;

    final apple = EcButton(
      label: compact ? 'Apple' : 'Continue with Apple',
      variant: EcButtonVariant.black,
      size: compact ? EcButtonSize.medium : EcButtonSize.large,
      expand: true,
      busy: form.isRunning(AuthAction.apple),
      leading: const Icon(Icons.apple, size: 20, color: Colors.white),
      onPressed: idle ? controller.signInWithApple : null,
    );
    final google = EcButton.secondary(
      label: compact ? 'Google' : 'Continue with Google',
      size: compact ? EcButtonSize.medium : EcButtonSize.large,
      expand: true,
      busy: form.isRunning(AuthAction.google),
      leading: const GoogleMark(),
      onPressed: idle ? controller.signInWithGoogle : null,
    );

    if (!Features.appleSignIn) return google;
    if (compact) {
      return Row(children: [Expanded(child: apple), const SizedBox(width: 10), Expanded(child: google)]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [apple, const SizedBox(height: 10), google]);
  }
}
