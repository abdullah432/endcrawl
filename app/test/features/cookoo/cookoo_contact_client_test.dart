import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/features/cookoo/data/cookoo_contact_client.dart';

void main() {
  late HttpServer server;
  late HttpCookooContactClient client;
  final requests = <(HttpHeaders, Map<String, Object?>)>[];
  var status = 200;
  var reply = '{"ok":true}';

  setUp(() async {
    requests.clear();
    status = 200;
    reply = '{"ok":true}';
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = jsonDecode(await utf8.decodeStream(request)) as Map<String, Object?>;
      requests.add((request.headers, body));
      request.response
        ..statusCode = status
        ..write(reply);
      await request.response.close();
    });
    client = HttpCookooContactClient(Uri.parse('http://127.0.0.1:${server.port}/api/contact'));
  });

  tearDown(() => server.close(force: true));

  test('posts JSON as the website does, from the cookoo.dev origin', () async {
    expect(await client.send({'name': 'Amira'}), CookooDelivery.sent);
    final (headers, body) = requests.single;
    expect(headers.value('origin'), 'https://cookoo.dev');
    expect(headers.contentType?.mimeType, 'application/json');
    expect(body, {'name': 'Amira'});
  });

  test('a 2xx without {"ok": true} is not a send', () async {
    reply = '{"ok":false}';
    expect(await client.send({}), CookooDelivery.rejected);
  });

  test('refusals are final; rate limits and server errors are retried', () async {
    status = 403;
    expect(await client.send({}), CookooDelivery.rejected);
    status = 429;
    expect(await client.send({}), CookooDelivery.retry);
    status = 500;
    expect(await client.send({}), CookooDelivery.retry);
  });

  test('no connection is retried', () async {
    await server.close(force: true);
    expect(await client.send({}), CookooDelivery.retry);
  });
}
