import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Creating an account with an email address.
///
/// A separate screen from signing in, not a mode flag on one: the button
/// says what it does, the autofill hint is `newPassword` without anything
/// having to check state, and nobody ever lands on "Sign in" while intending
/// the opposite.
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Drives the live length hint under the field.
    _password.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() => setState(() {});

  @override
  void dispose() {
    _password.removeListener(_onPasswordChanged);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authControllerProvider);
    final typed = _password.text.length;
    final longEnough = typed >= minimumPasswordLength;

    return AuthScaffold(
      title: 'Create account',
      subtitle: 'Keeps your projects together across every device you sign in on.',
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
          isNewPassword: true,
          hint: 'At least $minimumPasswordLength characters',
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: EcSpace.s2),
        // Said before submitting rather than after being rejected: the rule
        // is trivial and there is no reason to make a round trip teach it.
        Row(
          children: [
            Icon(
              longEnough ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: longEnough ? EcColors.accentPrimary : EcColors.textDisabled,
            ),
            const SizedBox(width: EcSpace.s2),
            Text(
              'At least $minimumPasswordLength characters',
              style: TextStyle(
                fontSize: 12,
                color: longEnough ? EcColors.accentPrimary : EcColors.textTertiary,
              ),
            ),
          ],
        ),
        AuthBanner.forFailure(form.failure),
        const SizedBox(height: EcSpace.s5),
        AuthPrimaryButton(label: 'Create account', busy: form.busy, onPressed: _submit),
      ],
    );
  }

  void _submit() {
    ref.read(authControllerProvider.notifier).createAccount(
          email: _email.text,
          password: _password.text,
        );
  }
}
