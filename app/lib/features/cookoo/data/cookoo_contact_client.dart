import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// How a contact request went.
enum CookooDelivery {
  /// The site accepted it.
  sent,

  /// No connection, a timeout or a server error — worth trying again later.
  retry,

  /// The site refused it (4xx); sending it again won't help.
  rejected,
}

/// Posts the contact form to cookoo.dev. An interface so tests never touch
/// the network.
///
/// The body is the website form's own: `name`, `email`, `message`,
/// `budget`, the empty `website` spam trap and a `requestId` that stays the
/// same across retries.
abstract interface class CookooContactClient {
  Future<CookooDelivery> send(Map<String, Object?> payload);
}

class HttpCookooContactClient implements CookooContactClient {
  final Uri endpoint;
  final Duration timeout;

  const HttpCookooContactClient(this.endpoint, {this.timeout = const Duration(seconds: 15)});

  @override
  Future<CookooDelivery> send(Map<String, Object?> payload) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.postUrl(endpoint).timeout(timeout);
      request.headers.contentType = ContentType.json;
      // The API only accepts posts that come from cookoo.dev itself.
      request.headers.set('Origin', 'https://cookoo.dev');
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close().timeout(timeout);
      final body = await utf8.decodeStream(response);
      return switch (response.statusCode) {
        // As on the site: only `{"ok": true}` counts as sent.
        >= 200 && < 300 => _ok(body) ? CookooDelivery.sent : CookooDelivery.rejected,
        408 || 429 => CookooDelivery.retry,
        >= 400 && < 500 => CookooDelivery.rejected,
        _ => CookooDelivery.retry,
      };
    } on SocketException {
      return CookooDelivery.retry;
    } on HttpException {
      return CookooDelivery.retry;
    } on TimeoutException {
      return CookooDelivery.retry;
    } on HandshakeException {
      return CookooDelivery.retry;
    } finally {
      client.close(force: true);
    }
  }

  static bool _ok(String body) {
    try {
      return (jsonDecode(body) as Map)['ok'] == true;
    } on Object {
      return false;
    }
  }
}

/// The web build: a page can't set the Origin header the API requires, so
/// the form points people to email instead.
class UnavailableCookooContactClient implements CookooContactClient {
  const UnavailableCookooContactClient();

  @override
  Future<CookooDelivery> send(Map<String, Object?> payload) async => CookooDelivery.rejected;
}
