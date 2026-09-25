/// An in-app legal page: a dated title, a plain-language summary, and
/// numbered sections (7.5). Privacy policy and terms share the layout.
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

// PLACEHOLDER COPY — from the design, for legal to replace before release.
const privacyPolicy = LegalDocument(
  title: 'Privacy policy',
  lastUpdated: '1 September 2026',
  summaryLead: 'The short version.',
  summary: 'We collect what we need to sync your projects and run the app. We never sell it, and you can delete it any time.',
  sections: [
    LegalSection('What we collect',
        'Your name, email and sign-in method; the projects, blocks and renders you create; and basic device information needed to run and fix the app.'),
    LegalSection('How we use it',
        'To sync your projects, process renders, provide support and keep the service secure. We don’t sell your data.'),
    LegalSection('Ads on the free plan',
        'Free accounts see ads in two places. With personalised ads off, ad partners receive only coarse context such as country and app version.'),
    LegalSection('Storage and retention',
        'Data is stored encrypted. When you delete your account it is removed immediately, and backups are purged within 30 days.'),
    LegalSection('Your rights',
        'You can download, correct or delete your data at any time from Settings, or by contacting us.'),
  ],
);

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
    LegalSection('Subscriptions', 'Pro is billed by Apple and renews until you cancel in App Store settings. After it ends nothing is deleted: three projects stay editable and ads come back.'),
    LegalSection('Ending', 'You can delete your account at any time from Settings. We may suspend accounts that abuse the service.'),
  ],
);
