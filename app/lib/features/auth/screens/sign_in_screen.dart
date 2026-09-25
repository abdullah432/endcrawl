import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_fields.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../data/repositories/auth_repository.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_navigation.dart';
import '../widgets/social_sign_in_buttons.dart';
import 'create_account_screen.dart';
import 'reset_password_screen.dart';

/// 0.2 — signing in with email.
///
/// A wrong password is reported under the password field, naming both ways
/// forward (try again, or reset). Apple and Google stay on the screen for
/// people who forget how they signed up.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => ref.read(authControllerProvider.notifier).signIn(email: _email.text, password: _password.text);

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authControllerProvider);

    return EcScaffold(
      topBar: const EcTopBar(),
      body: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EcHeadline('Welcome back.'),
            const SizedBox(height: 16),
            Text('Sign in with the email you used to create your account.', style: context.type.body),
            const SizedBox(height: 22),
            EcTextField(
              controller: _email,
              label: 'Email',
              hint: 'you@studio.com',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              error: form.errorFor(AuthField.email),
            ),
            const SizedBox(height: 14),
            EcPasswordField(
              controller: _password,
              error: form.errorFor(AuthField.password),
              onSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: EcButton.text(
                label: 'Forgot password?',
                size: EcButtonSize.small,
                onPressed: form.busy
                    ? null
                    : () => pushAuthScreen(context, ref, ResetPasswordScreen(initialEmail: _email.text)),
              ),
            ),
            const SizedBox(height: 6),
            AuthErrorBanner(form.formError),
            EcButton(label: 'Sign in', busy: form.isRunning(AuthAction.email), onPressed: form.busy ? null : _submit),
            const SizedBox(height: 16),
            const EcOrDivider(),
            const SizedBox(height: 16),
            const SocialSignInButtons(compact: true),
            const Spacer(),
            const SizedBox(height: 16),
            EcInlineLink(
              lead: 'New to LastReel?',
              action: 'Create account',
              onTap: form.busy ? null : () => replaceAuthScreen(context, ref, const CreateAccountScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
