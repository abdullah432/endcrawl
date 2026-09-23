import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../models/legal_document.dart';

/// A readable legal page in the app, not a web view (7.5). Used for both the
/// privacy policy and the terms, from onboarding and from Settings.
class LegalDocumentScreen extends StatelessWidget {
  final LegalDocument document;

  const LegalDocumentScreen({super.key, required this.document});

  static Future<void> open(BuildContext context, LegalDocument document) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LegalDocumentScreen(document: document)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return EcScaffold(
      topBar: EcTopBar(
        trailing: EcButton.text(
          label: 'Share',
          size: EcButtonSize.small,
          onPressed: () => SharePlus.instance.share(ShareParams(text: document.toPlainText(), subject: document.title)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 40),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EcEyebrow('Last updated · ${document.lastUpdated}'),
          const SizedBox(height: 14),
          Text(document.title, style: t.displayL.copyWith(fontSize: 46)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.accentWash,
              border: Border.all(color: p.accentLine),
              borderRadius: BorderRadius.circular(EcRadius.row),
            ),
            child: Text.rich(
              TextSpan(
                style: t.body.copyWith(fontSize: 13, color: p.ink),
                children: [
                  TextSpan(text: '${document.summaryLead} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: document.summary),
                ],
              ),
            ),
          ),
          for (final (i, section) in document.sections.indexed) ...[
            const SizedBox(height: 14),
            Text('${i + 1}. ${section.heading}', style: t.titleM.copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(section.body, style: t.body.copyWith(height: 1.6)),
          ],
        ],
      ),
    );
  }
}
