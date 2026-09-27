/// An in-app legal page: a dated title, a plain-language summary, and
/// numbered sections (7.5). Used for the terms; the privacy policy is the
/// published web page, `AppLinks.privacyPolicy`.
///
/// Held as data, not markup, so legal can replace the copy without touching
/// a widget. The text below is the design's placeholder, flagged as such.
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

// PLACEHOLDER COPY — the design says "Terms uses the same layout" but gives
// no text; these sections mirror the product's actual rules.
const termsOfService = LegalDocument(
  title: 'Terms of service',
  lastUpdated: '1 September 2026',
  summaryLead: 'The short version.',
  summary: 'Your credits are yours. Use LastReel to make them, and don’t use it to hurt anyone.',
  sections: [
    LegalSection('Your account', 'You need an account to keep projects. Keep your sign-in details to yourself; you are responsible for what happens under your account.'),
    LegalSection('Your content', 'You own the projects and renders you make. We store them only to sync and render them for you.'),
    LegalSection('Plans', 'The free plan keeps three projects and shows ads. Pro removes the cap and the ads. Every tool, codec and resolution is on both plans.'),
    LegalSection('Subscriptions', 'Pro is billed by your app store and renews until you cancel in its subscription settings. After it ends nothing is deleted: three projects stay editable and ads come back.'),
    LegalSection('Ending', 'You can delete your account at any time from Settings. We may suspend accounts that abuse the service.'),
  ],
);
