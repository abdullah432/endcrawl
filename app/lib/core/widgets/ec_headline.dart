import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// A serif headline whose last words are set in italic — "Reset your
/// *password.*", "End credits that roll *like the real thing.*" — the
/// design's signature title treatment.
class EcHeadline extends StatelessWidget {
  final String lead;
  final String? emphasis;
  final TextStyle? style;
  final TextAlign textAlign;

  const EcHeadline(this.lead, {super.key, this.emphasis, this.style, this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final base = style ?? context.type.displayL;
    // A lead that already ends in a space or line break — "Unlimited
    // projects.\n" — needs no separator; adding one would indent the italic
    // line or double the gap.
    final separated = emphasis == null || lead.endsWith(' ') || lead.endsWith('\n');
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: separated ? lead : '$lead '),
          if (emphasis != null) TextSpan(text: emphasis, style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
