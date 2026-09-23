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
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: emphasis == null ? lead : '$lead '),
          if (emphasis != null) TextSpan(text: emphasis, style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
