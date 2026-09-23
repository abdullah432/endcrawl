import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

/// Leaving the app: Mail, support email, web pages, the App Store.
///
/// An interface so screens that open things can be tested without a
/// platform channel, and so the "is there a Mail app" decision lives in one
/// place.
abstract interface class ExternalLinks {
  /// Opens the Mail app's inbox — "Open Mail" on 0.4 and 0.5.
  Future<bool> openMailApp();

  Future<bool> openUrl(Uri uri);

  Future<bool> composeEmail(String to, {String? subject});
}

class UrlLauncherLinks implements ExternalLinks {
  const UrlLauncherLinks();

  @override
  Future<bool> openMailApp() async {
    // iOS: `message://` opens Mail at the inbox. Android has no URL for
    // "an inbox"; the closest honest thing is the mail chooser via mailto:.
    final uri = Platform.isIOS ? Uri.parse('message://') : Uri(scheme: 'mailto');
    return _launch(uri);
  }

  @override
  Future<bool> openUrl(Uri uri) => _launch(uri);

  @override
  Future<bool> composeEmail(String to, {String? subject}) => _launch(
        Uri(scheme: 'mailto', path: to, query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}'),
      );

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
