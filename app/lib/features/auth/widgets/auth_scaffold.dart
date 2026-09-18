import 'package:flutter/material.dart';

import '../../../core/result.dart';
import '../../../core/theme/tokens.dart';

/// The chrome every credential screen shares: back button, wordmark, title,
/// one column at a comfortable reading measure, and a keyboard-safe scroll.
///
/// It exists so the three screens behind the welcome screen cannot drift
/// apart in spacing, type scale or where the error banner appears — moving
/// between them should feel like one surface changing its question, not like
/// three screens someone built on different days.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcColors.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left, size: 26, color: EcColors.textSecondary),
          tooltip: 'Back',
        ),
        title: const Text(
          'ENDCRAWL',
          style: TextStyle(
            fontFamily: EcFonts.archivoNarrow,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 4,
            color: EcColors.textTertiary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(EcSpace.s5, EcSpace.s4, EcSpace.s5, EcSpace.s7),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: EcFonts.archivoNarrow,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: EcColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: EcSpace.s2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: EcColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: EcSpace.s6),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's one primary action button, so every screen's main affordance is
/// the same height, shape and weight — and so the busy spinner replaces the
/// label without the button changing size under the user's thumb.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: EcColors.accentPrimary,
        foregroundColor: EcColors.accentInk,
        disabledBackgroundColor: EcColors.accentDim,
        disabledForegroundColor: EcColors.accentInk,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: EcColors.accentInk),
            )
          : Text(label),
    );
  }
}

/// A labelled text field in the app's dark treatment.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: EcSpace.s1, bottom: EcSpace.s2),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: EcColors.textTertiary,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          autofocus: autofocus,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          style: const TextStyle(fontSize: 15, color: EcColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: EcColors.textDisabled, fontSize: 14),
            filled: true,
            fillColor: EcColors.surfaceRaised,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: EcSpace.s4, vertical: 16),
            border: _border(EcColors.borderHairline),
            enabledBorder: _border(EcColors.borderHairline),
            focusedBorder: _border(EcColors.accentPrimary),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(EcRadius.md),
        borderSide: BorderSide(color: color),
      );
}

enum AuthBannerTone { error, notice }

/// One error/notice treatment, in one position on every screen, so the user
/// learns where to look exactly once.
class AuthBanner extends StatelessWidget {
  final String message;
  final AuthBannerTone tone;

  const AuthBanner({super.key, required this.message, this.tone = AuthBannerTone.error});

  /// Renders nothing when there is nothing to say, so callers can drop it
  /// straight into a column without a conditional spread.
  static Widget forFailure(AppFailure? failure) {
    if (failure == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: EcSpace.s4),
      child: AuthBanner(message: failure.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isError = tone == AuthBannerTone.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: EcSpace.s3, vertical: 11),
      decoration: BoxDecoration(
        color: isError ? EcColors.warnWash : EcColors.accentWash,
        border: Border.all(
          color: isError ? EcColors.warn.withValues(alpha: .4) : EcColors.accentDim,
        ),
        borderRadius: BorderRadius.circular(EcRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: isError ? EcColors.warn : EcColors.accentPrimary,
          ),
          const SizedBox(width: EcSpace.s2),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: isError ? EcColors.warn : EcColors.accentPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A password field with a show/hide toggle. Stateful so each screen doesn't
/// have to carry the obscure flag itself.
class AuthPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool isNewPassword;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const AuthPasswordField({
    super.key,
    required this.controller,
    this.label = 'PASSWORD',
    this.hint,
    this.isNewPassword = false,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AuthField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      obscure: _obscure,
      // A visibility toggle rather than a second "confirm password" field:
      // it is one control instead of one more thing to type, and it lets the
      // user actually check what they typed.
      autofillHints: widget.isNewPassword
          ? const [AutofillHints.newPassword]
          : const [AutofillHints.password],
      textInputAction: TextInputAction.done,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      suffix: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 18,
          color: EcColors.textTertiary,
        ),
        tooltip: _obscure ? 'Show password' : 'Hide password',
      ),
    );
  }
}
