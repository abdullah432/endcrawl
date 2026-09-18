import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_navigation.dart';
import '../widgets/auth_scaffold.dart';

/// Requesting a password reset link.
///
/// Its own screen rather than a link that silently fires off whatever is in
/// the sign-in form: sending mail on someone's behalf deserves a visible
/// before and after, and this one has both.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _email = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authControllerProvider);

    if (form.resetRequestedFor case final address?) {
      return _SentConfirmation(address: address);
    }

    return AuthScaffold(
      title: 'Reset password',
      subtitle: 'We\'ll send a link that lets you set a new one.',
      children: [
        AuthField(
          controller: _email,
          label: 'EMAIL',
          hint: 'you@studio.com',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          autofocus: widget.initialEmail.isEmpty,
          onSubmitted: (_) => _submit(),
        ),
        AuthBanner.forFailure(form.failure),
        const SizedBox(height: EcSpace.s5),
        AuthPrimaryButton(label: 'Send reset link', busy: form.busy, onPressed: _submit),
      ],
    );
  }

  void _submit() => ref.read(authControllerProvider.notifier).sendPasswordReset(_email.text);
}

/// The after state.
///
/// The wording is deliberately conditional. Firebase will not tell us whether
/// an account exists for that address — its enumeration protection exists to
/// stop exactly that — and it would be dishonest for this screen to claim
/// more certainty than the request actually has.
class _SentConfirmation extends ConsumerWidget {
  final String address;

  const _SentConfirmation({required this.address});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthScaffold(
      title: 'Check your inbox',
      subtitle: 'If an account exists for $address, a reset link is on its way. '
          'It can take a minute, and it is worth a look in spam.',
      children: [
        const SizedBox(height: EcSpace.s2),
        AuthPrimaryButton(
          label: 'Back to sign in',
          busy: false,
          onPressed: () => popAuthScreen(context, ref),
        ),
      ],
    );
  }
}
