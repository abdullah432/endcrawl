export 'legal_documents.dart';

/// An in-app legal page: a dated title, a plain-language summary, and
/// numbered sections (7.5). Used for the terms; the privacy policy is the
/// published web page, `AppLinks.privacyPolicy`.
///
/// Held as data, not markup; generated document data lives separately.
class LegalDocument {
  final String title;
  final String lastUpdated;
  final String summaryLead;
  final String summary;
  final List<LegalSection> sections;

  const LegalDocument({
    required this.title,
    required this.lastUpdated,
    required this.summaryLead,
    required this.summary,
    required this.sections,
  });

  /// Plain text for the share sheet.
  String toPlainText() => [
        title,
        'Last updated · $lastUpdated',
        '$summaryLead $summary',
        for (final (i, s) in sections.indexed) '${i + 1}. ${s.heading}\n${s.body}',
      ].join('\n\n');
}

class LegalSection {
  final String heading;
  final String body;
  const LegalSection(this.heading, this.body);
}
