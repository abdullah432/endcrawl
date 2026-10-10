import 'package:flutter/foundation.dart';

/// Addresses the app links out to. Last Reel's public pages live on
/// cookoo.dev, the COOKOO Technologies site.
abstract final class AppLinks {
  static const supportEmail = 'hello@cookoo.dev';

  /// Tagged studio link: native browsers may omit their app referrer.
  static final studio = Uri.https('cookoo.dev', '/', {
    'utm_source': 'lastreel',
    'utm_medium': 'referral',
    'utm_campaign': 'made_by_cookoo',
    'utm_content': 'settings_footer',
  });

  /// COOKOO's case studies, tagged so the site knows the visit came from
  /// the studio card in Settings.
  static final cookooCases = Uri.https('cookoo.dev', '/cases', {'from': 'lastreel'});
  static Uri cookooCase(String slug) => Uri.https('cookoo.dev', '/cases/$slug', {'from': 'lastreel'});

  /// Same backend as the contact form on cookoo.dev.
  // TODO: confirm the endpoint with the website before release.
  static final cookooContact = Uri.parse('https://cookoo.dev/api/contact');

  /// Answers to common questions, with a way to reach support.
  static final helpCentre = Uri.parse('https://cookoo.dev/lastreel/help');

  /// The published policy, hosted on cookoo.dev — the same page the store
  /// listings link to, so there is only one version to keep current.
  static final privacyPolicy = Uri.parse('https://cookoo.dev/lastreel/privacy-policy');

  /// LastReel on Google Play — where the web sends people to subscribe
  /// (D2's button and QR code).
  static final playStoreListing = Uri.parse('https://play.google.com/store/apps/details?id=com.lastreel.app');

  /// Google Play's subscriptions page for LastReel — "Manage in Google
  /// Play" on the web, which never bills.
  static final playSubscriptions =
      Uri.parse('https://play.google.com/store/account/subscriptions?package=com.lastreel.app');

  static String get storeName => defaultTargetPlatform == TargetPlatform.android ? 'Google Play' : 'App Store';
  static Uri get manageSubscriptions => Uri.parse(defaultTargetPlatform == TargetPlatform.android
      ? 'https://play.google.com/store/account/subscriptions?package=com.lastreel.app'
      : 'https://apps.apple.com/account/subscriptions');
}
