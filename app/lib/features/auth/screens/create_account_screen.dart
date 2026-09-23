import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_fields.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/password_policy.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_navigation.dart';
import '../widgets/legal_consent.dart';
import 'sign_in_screen.dart';

/// 0.3 — creating an account with email.
///
/// Three fields. The password rules tick off as you type, from the same
/// [PasswordPolicy] the controller enforces, and the marketing opt-in is off
/// by default and marked optional.
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _optIn = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _password.removeListener(_rebuild);
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => ref.read(authControllerProvider.notifier).createAccount(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        marketingOptIn: _optIn,
      );

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authControllerProvider);
    final t = context.type;

    return EcScaffold(
      topBar: const EcTopBar(),
      body: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const EcHeadline('Create your', emphasis: 'account.'),
            const SizedBox(height: 20),
            EcTextField(
              controller: _name,
              label: 'Name',
              hint: 'As it should appear on your profile',
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              error: form.errorFor(AuthField.name),
            ),
            const SizedBox(height: 12),
            EcTextField(
              controller: _email,
              label: 'Email',
              hint: 'you@studio.com',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              error: form.errorFor(AuthField.email),
            ),
            const SizedBox(height: 12),
            EcPasswordField(
              controller: _password,
              isNewPassword: true,
              error: form.errorFor(AuthField.password),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            for (final rule in PasswordPolicy.rules)
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 6),
                child: EcCheckItem(label: rule.label, met: rule.test(_password.text)),
              ),
            const SizedBox(height: 6),
            EcCheckbox(
              value: _optIn,
              onChanged: (v) => setState(() => _optIn = v),
              label: Text.rich(
                TextSpan(
                  style: t.bodyS,
                  children: [
                    const TextSpan(text: 'Email me about new features '),
                    TextSpan(text: '· optional', style: TextStyle(color: context.palette.muted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            AuthErrorBanner(form.formError),
            EcButton(
              label: 'Create account',
              busy: form.isRunning(AuthAction.email),
              onPressed: form.busy ? null : _submit,
            ),
            const SizedBox(height: 14),
            const LegalConsent(lead: 'By creating an account you agree to the'),
            const Spacer(),
            const SizedBox(height: 16),
            EcInlineLink(
              lead: 'Already have an account?',
              action: 'Sign in',
              onTap: form.busy ? null : () => replaceAuthScreen(context, ref, const SignInScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
