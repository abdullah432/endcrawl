import 'package:lastreel/core/services/external_links.dart';

/// Records what the app tried to open instead of leaving the test.
class FakeExternalLinks implements ExternalLinks {
  int mailOpened = 0;
  final opened = <Uri>[];
  final composed = <String>[];
  final composedBodies = <String?>[];

  @override
  Future<bool> openMailApp() async {
    mailOpened++;
    return true;
  }

  @override
  Future<bool> openUrl(Uri uri) async {
    opened.add(uri);
    return true;
  }

  @override
  Future<bool> composeEmail(String to, {String? subject, String? body}) async {
    composed.add(to);
    composedBodies.add(body);
    return true;
  }
}
