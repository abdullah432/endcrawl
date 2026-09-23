import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_logo.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/screens/create_account_screen.dart';
import '../../auth/screens/sign_in_screen.dart';
import '../../auth/widgets/auth_error_banner.dart';
import '../../auth/widgets/auth_navigation.dart';
import '../../auth/widgets/legal_consent.dart';
import '../../auth/widgets/social_sign_in_buttons.dart';
import '../widgets/roll_hero.dart';

/// 0.1 — the first screen, and the whole of onboarding.
///
/// No feature carousel: the credits rolling in the monitor are the
/// explanation. One tap on Apple or Google creates the account or signs in;
/// email is there for everyone else.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(authControllerProvider);
    final t = context.type;

    return EcScaffold(
      // The safe area already clears the home indicator, so the bottom
      // padding is only a breath.
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const EcLogo(),
              const Spacer(),
              EcButton.text(
                label: 'Sign in',
                size: EcButtonSize.small,
                onPressed: form.busy ? null : () => pushAuthScreen(context, ref, const SignInScreen()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const RollHero(),
          const SizedBox(height: 26),
          const EcHeadline('End credits that roll', emphasis: 'like the real thing.'),
          const SizedBox(height: 12),
          Text('Build the crawl on your phone, time it to the frame and export it for the edit.', style: t.body),
          const Spacer(),
          const SizedBox(height: 24),
          AuthErrorBanner(form.formError),
          const SocialSignInButtons(),
          const SizedBox(height: 4),
          EcButton(
            label: 'Sign up with email',
            variant: EcButtonVariant.plain,
            size: EcButtonSize.medium,
            expand: true,
            onPressed: form.busy ? null : () => pushAuthScreen(context, ref, const CreateAccountScreen()),
          ),
          const SizedBox(height: 6),
          const LegalConsent(),
        ],
      ),
    );
  }
}
