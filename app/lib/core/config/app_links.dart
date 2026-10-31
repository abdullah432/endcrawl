import 'package:flutter/foundation.dart';

/// Addresses the app links out to. Last Reel's public pages live on
/// cookoo.dev, the COOKOO Technologies site.
abstract final class AppLinks {
  static final androidDownload = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.lastreel.app',
  );
  static final Uri? iosDownload =
      const String.fromEnvironment('IOS_APP_STORE_URL').isEmpty
      ? null
      : Uri.tryParse(const String.fromEnvironment('IOS_APP_STORE_URL'));
  static const supportEmail = 'hello@cookoo.dev';

  /// Tagged studio link: native browsers may omit their app referrer.
  static final studio = Uri.https('cookoo.dev', '/', {
    'utm_source': 'lastreel',
    'utm_medium': 'referral',
    'utm_campaign': 'made_by_cookoo',
    'utm_content': 'settings_footer',
  });

  /// COOKOO's case studies, tagged so cookoo.dev's own analytics credit the
  /// visit to the From the makers card in LastReel, and which part of it.
  static final cookooCases = cookooSite('/cases', content: 'contact');
  static Uri cookooCase(String slug, {String content = 'card'}) => cookooSite('/cases/$slug', content: content);

  /// A cookoo.dev page with LastReel's campaign tags.
  static Uri cookooSite(String path, {required String content}) => Uri.https('cookoo.dev', path, {
    'from': 'lastreel',
    'utm_source': 'lastreel',
    'utm_medium': 'app',
    'utm_campaign': 'from_the_makers',
    'utm_content': content,
  });

  /// A Google Play listing with an install referrer, so the other app's
  /// Play Console credits installs to LastReel.
  static Uri playListing(String id) => Uri.https('play.google.com', '/store/apps/details', {
    'id': id,
    'referrer': 'utm_source=lastreel&utm_medium=app&utm_campaign=from_the_makers',
  });

  /// Same backend as the contact form on cookoo.dev.
  // TODO: confirm the endpoint with the website before release.
  static final cookooContact = Uri.parse('https://cookoo.dev/api/contact');

  /// Answers to common questions, with a way to reach support.
  static final helpCentre = Uri.parse('https://cookoo.dev/lastreel/help');

  /// The published policy, hosted on cookoo.dev — the same page the store
  /// listings link to, so there is only one version to keep current.
  static final privacyPolicy = Uri.parse(
    'https://cookoo.dev/lastreel/privacy-policy',
  );

  /// The web app — the desk editor, Pro on a computer (1.8b's link).
  static final webApp = Uri.parse('https://app.lastreel.cookoo.dev');

  /// COOKOO's other apps on Google Play — Settings → Explore our other apps.
  static final textCrawlListing = playListing('com.kukustudio.textcrawler');
  static final aksListing = playListing('com.cookoo.aks');

  /// LastReel on Google Play — where the web sends people to subscribe
  /// (D2's button and QR code).
  static final playStoreListing = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.lastreel.app',
  );

  /// LastReel on the App Store. Unset until the listing is public; until
  /// then nothing links to the iPhone app.
  static const Uri? appStoreListing = null;

  /// The app's store page for this device — the web's "Open the LastReel
  /// app" (1.8c). Null on an iPhone or iPad until [appStoreListing] is set.
  static Uri? get appListing => switch (defaultTargetPlatform) {
    TargetPlatform.iOS => appStoreListing,
    _ => playStoreListing,
  };

  /// Google Play's subscriptions page for LastReel — "Manage in Google
  /// Play" on the web, which never bills.
  static final playSubscriptions = Uri.parse(
    'https://play.google.com/store/account/subscriptions?package=com.lastreel.app',
  );

  static String get storeName => defaultTargetPlatform == TargetPlatform.android
      ? 'Google Play'
      : 'App Store';
  static Uri get manageSubscriptions => Uri.parse(
    defaultTargetPlatform == TargetPlatform.android
        ? 'https://play.google.com/store/account/subscriptions?package=com.lastreel.app'
        : 'https://apps.apple.com/account/subscriptions',
  );
}
