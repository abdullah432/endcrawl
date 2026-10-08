import 'dart:math' as math;

import '../../../core/services/clarity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../auth/controllers/auth_controller.dart' show looksLikeEmail;
import '../controllers/cookoo_contact_controller.dart';
import '../controllers/cookoo_promo_controller.dart';
import '../data/cookoo_contact_client.dart';
import '../models/cookoo_content.dart';
import '../widgets/cookoo_style.dart';
import 'cookoo_sent_screen.dart';

/// "Tell us your idea." — the short brief to COOKOO, opened from any slide
/// of the studio card. Name, a valid email and the idea are required;
/// need and budget are chips with a default.
class CookooContactScreen extends ConsumerStatefulWidget {
  /// The slide it was opened from, `s1`…`s4`.
  final String source;
  final CookooNeed need;

  const CookooContactScreen({super.key, required this.source, this.need = CookooNeed.newApp});

  static Future<void> open(BuildContext context, {required String source, CookooNeed need = CookooNeed.newApp}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CookooContactScreen(source: source, need: need),
        ),
      );

  @override
  ConsumerState<CookooContactScreen> createState() => _CookooContactScreenState();
}

class _CookooContactScreenState extends ConsumerState<CookooContactScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _idea = TextEditingController();
  final _emailFocus = FocusNode();
  late CookooNeed _need = widget.need;
  CookooBudget _budget = CookooBudget.notSure;
  bool _sending = false;
  bool _emailTouched = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _email, _idea]) {
      c.addListener(_changed);
    }
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus && _email.text.trim().isNotEmpty) setState(() => _emailTouched = true);
    });
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _idea.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  bool get _complete => _name.text.trim().isNotEmpty && looksLikeEmail(_email.text) && _idea.text.trim().isNotEmpty;

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final name = _name.text.trim();
    final email = _email.text.trim();
    final idea = _idea.text.trim();
    final result = await ref
        .read(cookooContactControllerProvider)
        .submit(
          CookooContactRequest(
            need: _need,
            name: name,
            email: email,
            idea: idea,
            budget: _budget,
            source: widget.source,
          ),
        );
    if (!mounted) return;
    setState(() => _sending = false);
    if (result == CookooDelivery.rejected) {
      showEcToast(context, "That didn't go through. Check your details and try again.");
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            CookooSentScreen(name: name, email: email, idea: idea, need: _need, queued: result == CookooDelivery.retry),
      ),
    );
  }

  void _openSite() {
    ref.read(cookooPromoProvider.notifier).siteOpened('contact');
    ref.read(externalLinksProvider).openUrl(AppLinks.cookooCases);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    ref.watch(cookooAppVersionProvider); // Ready by the time "Send" is.
    final emailError = _emailTouched && !looksLikeEmail(_email.text) && !_emailFocus.hasFocus;
    // The bar's 24 px foot includes the home indicator where there is one.
    final foot = math.max(24 - MediaQuery.paddingOf(context).bottom, 8.0);

    return EcScaffold(
      topBar: const EcTopBar(),
      scrollable: false,
      padding: EdgeInsets.zero,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        // What people type here never appears in Clarity recordings.
        child: ClarityMask(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Intro(),
              const SizedBox(height: 22),
              _Labelled(
                label: 'WHAT DO YOU NEED?',
                gap: 10,
                child: _Choices<CookooNeed>(
                  values: CookooNeed.values,
                  selected: _need,
                  label: (n) => n.label,
                  onSelected: (n) => setState(() => _need = n),
                ),
              ),
              const SizedBox(height: 22),
              _Labelled(
                label: 'YOUR NAME',
                child: _Field(
                  controller: _name,
                  autofillHints: const [AutofillHints.name],
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(height: 22),
              _Labelled(
                label: 'EMAIL ADDRESS',
                child: _Field(
                  controller: _email,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  error: emailError ? 'Enter a valid email address.' : null,
                ),
              ),
              const SizedBox(height: 22),
              _Labelled(
                label: 'WHAT WOULD YOU LIKE TO BUILD?',
                child: _Field(controller: _idea, multiline: true, textCapitalization: TextCapitalization.sentences),
              ),
              const SizedBox(height: 22),
              _Labelled(
                label: 'BUDGET RANGE · OPTIONAL, USD',
                gap: 10,
                child: _Choices<CookooBudget>(
                  values: CookooBudget.values,
                  selected: _budget,
                  label: (b) => b.label,
                  onSelected: (b) => setState(() => _budget = b),
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, foot),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: p.line)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CookooInkButton(
              label: 'Send my idea',
              icon: Icons.send,
              busy: _sending,
              onPressed: _complete ? _send : null,
            ),
            const SizedBox(height: 4),
            CookooTextLink(label: 'See our work on cookoo.dev', onTap: _openSite),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.egg, size: 14, color: p.ink),
            const SizedBox(width: 6),
            Expanded(
              child: Text('COOKOO · APP DESIGN & BUILD · PAID SERVICE', style: context.cookooMono(10, tracking: 1.5)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(header: true, child: Text('Tell us your idea.', style: context.cookooSerif(38, height: 1))),
        const SizedBox(height: 8),
        Text(
          'No polished plan needed. A few lines is enough to start.',
          style: context.cookooUi(15, height: 1.5, color: p.ink2),
        ),
      ],
    );
  }
}

class _Labelled extends StatelessWidget {
  final String label;
  final Widget child;
  final double gap;
  const _Labelled({required this.label, required this.child, this.gap = 8});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: context.cookooMono(10, tracking: 2)),
        SizedBox(height: gap),
        child,
      ],
    );
  }
}

/// Single-select pills: ink with a check when selected, outlined otherwise.
class _Choices<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  const _Choices({required this.values, required this.selected, required this.label, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          Semantics(
            selected: value == selected,
            button: true,
            child: Material(
              color: value == selected ? p.inkSurface : Colors.transparent,
              shape: StadiumBorder(side: value == selected ? BorderSide.none : BorderSide(color: p.line2)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(value),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (value == selected) ...[Icon(Icons.check, size: 16, color: p.onInk), const SizedBox(width: 6)],
                      Flexible(
                        child: Text(
                          label(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.cookooUi(
                            14,
                            weight: value == selected ? FontWeight.w600 : FontWeight.w400,
                            color: value == selected ? p.onInk : p.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 50 px field (120 px minimum when multi-line): surface fill, hairline
/// border, 1.5 px ink border while focused.
class _Field extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final bool multiline;
  final String? error;

  const _Field({
    required this.controller,
    this.focusNode,
    this.keyboardType,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.multiline = false,
    this.error,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
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
    final focused = _focus.hasFocus;
    final error = widget.error;
    final style = context.cookooUi(16, height: widget.multiline ? 1.45 : null);
    final field = AnimatedContainer(
      duration: EcMotion.fast,
      constraints: BoxConstraints(minHeight: widget.multiline ? 120 : 50),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: widget.multiline ? 14 : 0),
      alignment: widget.multiline ? Alignment.topLeft : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(EcRadius.field),
        border: Border.all(color: focused ? p.ink : (error != null ? p.ink2 : p.line2), width: focused ? 1.5 : 1),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: widget.multiline ? TextInputType.multiline : widget.keyboardType,
        autofillHints: widget.autofillHints,
        textCapitalization: widget.textCapitalization,
        textInputAction: widget.multiline ? TextInputAction.newline : TextInputAction.next,
        minLines: widget.multiline ? 4 : 1,
        maxLines: widget.multiline ? 12 : 1,
        cursorColor: p.ink,
        style: style,
        decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
      ),
    );
    if (error == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        const SizedBox(height: 6),
        // The COOKOO screens use no red, so the hint is set in ink.
        Text(error, style: context.cookooUi(12.5, color: p.ink2)),
      ],
    );
  }
}
