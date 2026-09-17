import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../controllers/auth_controller.dart';

/// Email/password and Google sign-in, in the same cinema-grade dark
/// treatment as the rest of the app.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final registering = form.mode == AuthMode.register;

    return Scaffold(
      backgroundColor: EcColors.surfaceCanvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: EcSpace.s5, vertical: EcSpace.s6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ENDCRAWL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: EcFonts.archivoNarrow,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      letterSpacing: 6,
                      color: EcColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: EcSpace.s3),
                  Text(
                    registering
                        ? 'Create an account to keep your projects\nacross devices.'
                        : 'Sign in to reach your projects.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: EcColors.textSecondary),
                  ),
                  const SizedBox(height: EcSpace.s7),
                  _field(
                    controller: _email,
                    hint: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) => controller.clearMessages(),
                  ),
                  const SizedBox(height: EcSpace.s3),
                  _field(
                    controller: _password,
                    hint: 'Password',
                    obscure: _obscure,
                    autofillHints: registering
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    onChanged: (_) => controller.clearMessages(),
                    onSubmitted: (_) => _submit(),
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18,
                        color: EcColors.textTertiary,
                      ),
                    ),
                  ),
                  if (form.failure != null) ...[
                    const SizedBox(height: EcSpace.s3),
                    _Banner(message: form.failure!.message, tone: _BannerTone.error),
                  ],
                  if (form.notice != null) ...[
                    const SizedBox(height: EcSpace.s3),
                    _Banner(message: form.notice!, tone: _BannerTone.notice),
                  ],
                  const SizedBox(height: EcSpace.s4),
                  FilledButton(
                    onPressed: form.busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: EcColors.accentPrimary,
                      foregroundColor: EcColors.accentInk,
                      disabledBackgroundColor: EcColors.accentDim,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    child: form.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: EcColors.accentInk),
                          )
                        : Text(registering ? 'Create account' : 'Sign in'),
                  ),
                  if (!registering) ...[
                    const SizedBox(height: EcSpace.s2),
                    TextButton(
                      onPressed: form.busy ? null : () => controller.sendPasswordReset(_email.text),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(fontSize: 12.5, color: EcColors.textSecondary),
                      ),
                    ),
                  ],
                  const SizedBox(height: EcSpace.s4),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: EcColors.borderHairline)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: EcSpace.s3),
                        child: Text(
                          'OR',
                          style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: EcColors.textTertiary),
                        ),
                      ),
                      const Expanded(child: Divider(color: EcColors.borderHairline)),
                    ],
                  ),
                  const SizedBox(height: EcSpace.s4),
                  OutlinedButton.icon(
                    onPressed: form.busy ? null : controller.signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EcColors.textPrimary,
                      minimumSize: const Size.fromHeight(52),
                      side: const BorderSide(color: EcColors.borderStrong),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)),
                    ),
                    icon: const _GoogleMark(),
                    label: const Text('Continue with Google', style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(height: EcSpace.s5),
                  // Wrap, not Row: "Already have an account?" plus the button
                  // overflows a narrow phone on one line.
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        registering ? 'Already have an account?' : 'New here?',
                        style: const TextStyle(fontSize: 13, color: EcColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: form.busy
                            ? null
                            : () => controller.setMode(registering ? AuthMode.signIn : AuthMode.register),
                        child: Text(
                          registering ? 'Sign in' : 'Create one',
                          style: const TextStyle(fontSize: 13, color: EcColors.accentPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    ref.read(authControllerProvider.notifier).submitEmail(
          email: _email.text,
          password: _password.text,
        );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      style: const TextStyle(fontSize: 15, color: EcColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: EcColors.textTertiary),
        filled: true,
        fillColor: EcColors.surfaceRaised,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: EcSpace.s4, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EcRadius.md),
          borderSide: const BorderSide(color: EcColors.borderHairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EcRadius.md),
          borderSide: const BorderSide(color: EcColors.borderHairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EcRadius.md),
          borderSide: const BorderSide(color: EcColors.accentPrimary),
        ),
      ),
    );
  }
}

enum _BannerTone { error, notice }

class _Banner extends StatelessWidget {
  final String message;
  final _BannerTone tone;

  const _Banner({required this.message, required this.tone});

  @override
  Widget build(BuildContext context) {
    final isError = tone == _BannerTone.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: EcSpace.s3, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? EcColors.warnWash : EcColors.accentWash,
        border: Border.all(color: isError ? EcColors.warn.withValues(alpha: .4) : EcColors.accentDim),
        borderRadius: BorderRadius.circular(EcRadius.md),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.35,
          color: isError ? EcColors.warn : EcColors.accentPrimary,
        ),
      ),
    );
  }
}

/// The Google "G", drawn rather than shipped as an asset so there is no
/// image to keep in sync with the brand guidelines.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4285F4),
          height: 1.1,
        ),
      ),
    );
  }
}
