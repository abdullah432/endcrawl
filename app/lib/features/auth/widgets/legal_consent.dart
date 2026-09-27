import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/theme/theme_context.dart';
import '../../settings/models/legal_document.dart';
import '../../settings/screens/legal_document_screen.dart';

/// "By continuing you agree to the Terms and Privacy Policy." with both
/// documents one tap away: the terms in the app, the privacy policy on the
/// web.
class LegalConsent extends ConsumerStatefulWidget {
  final String lead;

  const LegalConsent({super.key, this.lead = 'By continuing you agree to the'});

  @override
  ConsumerState<LegalConsent> createState() => _LegalConsentState();
}

class _LegalConsentState extends ConsumerState<LegalConsent> {
  late final _terms = TapGestureRecognizer()..onTap = () => LegalDocumentScreen.open(context, termsOfService);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => ref.read(externalLinksProvider).openUrl(AppLinks.privacyPolicy);

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
