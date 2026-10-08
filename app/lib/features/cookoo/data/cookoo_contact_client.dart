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
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      return switch (response.statusCode) {
        >= 200 && < 300 => CookooDelivery.sent,
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
}
