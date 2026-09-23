import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
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
import '../widgets/resend_countdown.dart';

/// 0.4 — requesting a password reset link.
///
/// The sent state appears on the same screen, under the form, with a resend
/// countdown — so nobody taps twice and gets two emails.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String initialEmail;

  const ResetPasswordScreen({super.key, this.initialEmail = ''});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _send() => ref.read(authControllerProvider.notifier).sendPasswordReset(_email.text);

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final sentTo = form.resetSentTo;

    return EcScaffold(
      topBar: const EcTopBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EcHeadline('Reset your', emphasis: 'password.'),
          const SizedBox(height: 16),
          Text('Enter your account email. We’ll send a link to choose a new password.', style: context.type.body),
          const SizedBox(height: 16),
          EcTextField(
            controller: _email,
            label: 'Email',
            hint: 'you@studio.com',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            autofocus: widget.initialEmail.isEmpty,
            error: form.errorFor(AuthField.email),
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 16),
          AuthErrorBanner(form.formError),
          EcButton(
            label: 'Send reset link',
            busy: form.isRunning(AuthAction.reset),
            onPressed: form.busy || controller.resetCooldownLeft() > Duration.zero ? null : _send,
          ),
          if (sentTo != null) ...[
            const SizedBox(height: 22),
            // Conditional on purpose: Firebase won't say whether an account
            // exists for the address, and the copy shouldn't claim more
            // certainty than the request has.
            EcNotice(
              tone: EcTone.ok,
              title: 'Check your inbox',
              body: 'If there’s an account for $sentTo, a link is on its way. Not there in a minute? Check spam.',
              actions: [
                EcButton.secondary(
                  label: 'Open Mail',
                  size: EcButtonSize.medium,
                  onPressed: () => ref.read(externalLinksProvider).openMailApp(),
                ),
                ResendCountdown(
                  remaining: controller.resetCooldownLeft,
                  onResend: form.busy ? null : _send,
                ),
              ],
            ),
          ],
          const Spacer(),
          const SizedBox(height: 16),
          Center(
            child: EcButton.text(label: 'Back to sign in', onPressed: () => popAuthScreen(context, ref)),
          ),
        ],
      ),
    );
  }
}
