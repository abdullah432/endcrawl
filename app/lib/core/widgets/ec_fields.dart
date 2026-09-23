import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../theme/tokens.dart';

/// A labelled text field: 12 px label above a 52 px white field.
///
/// Three visual states from the design — rest (`line2` border), focused
/// (accent border + 4 px wash ring) and error (warn border + ring, with the
/// message underneath). The ring is drawn by a wrapping container rather than
/// Material's border so it can sit outside the field, as in the design.
class EcTextField extends StatefulWidget {
  final TextEditingController controller;

  /// Null when the caller labels the field itself (e.g. a mono section
  /// label on the rename sheet).
  final String? label;
  final String? hint;
  final String? error;
  final String? helper;

  /// Shown at the right of the helper line — "17/60".
  final String? counter;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final FocusNode? focusNode;

  /// Letter-spaced dots, as the design sets obscured passwords.
  final bool obscureSpacing;

  const EcTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.error,
    this.helper,
    this.counter,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
    this.focusNode,
    this.obscureSpacing = false,
  });

  @override
  State<EcTextField> createState() => _EcTextFieldState();
}

class _EcTextFieldState extends State<EcTextField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final hasError = widget.error != null;
    final focused = _focus.hasFocus;

    final borderColor = hasError ? p.warnFill : (focused ? p.accentSolid : p.line2);
    final ring = hasError ? p.warnWash : (focused ? p.accentWash : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[Text(widget.label!, style: t.label), const SizedBox(height: 7)],
        AnimatedContainer(
          duration: EcMotion.fast,
          height: 52,
          padding: const EdgeInsets.only(left: 16, right: 6),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(EcRadius.field),
            border: Border.all(color: borderColor, width: hasError || focused ? 1.5 : 1),
            boxShadow: ring == null ? null : [BoxShadow(color: ring, spreadRadius: 4)],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: widget.obscure,
                  obscuringCharacter: '•',
                  keyboardType: widget.keyboardType,
                  autofillHints: widget.autofillHints,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  autofocus: widget.autofocus,
                  maxLength: widget.maxLength,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: t.bodyL.copyWith(letterSpacing: widget.obscure && widget.obscureSpacing ? 2.7 : null),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    counterText: '',
                    hintText: widget.hint,
                    hintStyle: t.bodyL.copyWith(color: p.faint),
                  ),
                ),
              ),
              if (widget.suffix != null) widget.suffix! else const SizedBox(width: 10),
            ],
          ),
        ),
        if (hasError || widget.helper != null || widget.counter != null) ...[
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.error ?? widget.helper ?? '',
                  style: t.caption.copyWith(color: hasError ? p.warn : p.muted, height: 1.4),
                ),
              ),
              if (widget.counter != null) Text(widget.counter!, style: t.mono.copyWith(fontSize: 10)),
            ],
          ),
        ],
      ],
    );
  }
}

/// A password field with the design's "Show / Hide" text toggle.
class EcPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? error;
  final bool isNewPassword;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const EcPasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.hint,
    this.error,
    this.isNewPassword = false,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<EcPasswordField> createState() => _EcPasswordFieldState();
}

class _EcPasswordFieldState extends State<EcPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return EcTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      error: widget.error,
      obscure: _obscure,
      obscureSpacing: true,
      autofillHints: [widget.isNewPassword ? AutofillHints.newPassword : AutofillHints.password],
      textInputAction: TextInputAction.done,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      suffix: TextButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        style: TextButton.styleFrom(
          foregroundColor: context.palette.accent,
          textStyle: context.type.bodyS.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(44, 44),
        ),
        child: Text(_obscure ? 'Show' : 'Hide'),
      ),
    );
  }
}

/// A checklist line — the password rules on 0.3. Ticks green when [met].
class EcCheckItem extends StatelessWidget {
  final String label;
  final bool met;

  const EcCheckItem({super.key, required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      checked: met,
      child: Row(
        children: [
          AnimatedContainer(
            duration: EcMotion.fast,
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: met ? p.ok : null,
              shape: BoxShape.circle,
              border: met ? null : Border.all(color: p.line2, width: 1.5),
            ),
            child: met ? Icon(Icons.check_rounded, size: 11, color: p.onInk) : null,
          ),
          const SizedBox(width: 8),
          Text(label, style: context.type.label.copyWith(fontWeight: FontWeight.w400, color: met ? p.ok : p.muted)),
        ],
      ),
    );
  }
}

/// A 24 px rounded checkbox with a label — the marketing opt-in.
class EcCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget label;

  const EcCheckbox({super.key, required this.value, required this.onChanged, required this.label});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      checked: value,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              AnimatedContainer(
                duration: EcMotion.fast,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: value ? p.primary : null,
                  color: value ? null : p.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: value ? null : Border.all(color: p.line2, width: 1.5),
                ),
                child: value ? Icon(Icons.check_rounded, size: 16, color: p.onInk) : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: label),
            ],
          ),
        ),
      ),
    );
  }
}
