import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../settings/models/legal_document.dart';
import '../../settings/screens/legal_document_screen.dart';

/// "By continuing you agree to the Terms and Privacy Policy." with both
/// documents one tap away.
class LegalConsent extends StatefulWidget {
  final String lead;

  const LegalConsent({super.key, this.lead = 'By continuing you agree to the'});

  @override
  State<LegalConsent> createState() => _LegalConsentState();
}

class _LegalConsentState extends State<LegalConsent> {
  late final _terms = TapGestureRecognizer()..onTap = () => LegalDocumentScreen.open(context, termsOfService);
  late final _privacy = TapGestureRecognizer()..onTap = () => LegalDocumentScreen.open(context, privacyPolicy);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final link = TextStyle(color: context.palette.accent);
    return Text.rich(
      TextSpan(
        style: t.fine,
        children: [
          TextSpan(text: '${widget.lead} '),
          TextSpan(text: 'Terms', style: link, recognizer: _terms),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: link, recognizer: _privacy),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
