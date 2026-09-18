import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_navigation.dart';
import '../widgets/auth_scaffold.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';

/// Signing in with an email address. Only that — creating an account and
/// resetting a password are their own screens, reached from the two links at
/// the bottom.
class EmailSignInScreen extends ConsumerStatefulWidget {
  const EmailSignInScreen({super.key});

  @override
  ConsumerState<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends ConsumerState<EmailSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authControllerProvider);

    return AuthScaffold(
      title: 'Sign in',
      subtitle: 'Your projects are waiting.',
      children: [
        AuthField(
          controller: _email,
          label: 'EMAIL',
          hint: 'you@studio.com',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autofocus: true,
        ),
        const SizedBox(height: EcSpace.s4),
        AuthPasswordField(
          controller: _password,
          onSubmitted: (_) => _submit(),
        ),
        AuthBanner.forFailure(form.failure),
        const SizedBox(height: EcSpace.s5),
        AuthPrimaryButton(label: 'Sign in', busy: form.busy, onPressed: _submit),
        const SizedBox(height: EcSpace.s2),
        TextButton(
          onPressed: form.busy
              ? null
              : () => pushAuthScreen(
                    context,
                    ref,
                    // The reset screen starts from whatever was typed here,
                    // so nobody has to enter their address twice.
                    ForgotPasswordScreen(initialEmail: _email.text),
                  ),
          child: const Text(
            'Forgot password?',
            style: TextStyle(fontSize: 13, color: EcColors.textSecondary),
          ),
        ),
        const SizedBox(height: EcSpace.s4),
        const Divider(color: EcColors.borderHairline, height: 1),
        const SizedBox(height: EcSpace.s4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'New here?',
              style: TextStyle(fontSize: 13, color: EcColors.textSecondary),
            ),
            TextButton(
              onPressed: form.busy
                  ? null
                  : () => pushAuthScreen(context, ref, const CreateAccountScreen()),
              child: const Text(
                'Create an account',
                style: TextStyle(fontSize: 13, color: EcColors.accentPrimary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    ref.read(authControllerProvider.notifier).signIn(
          email: _email.text,
          password: _password.text,
        );
  }
}
