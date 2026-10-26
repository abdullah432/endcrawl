import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/config/firebase_auth_domain.dart';

void main() {
  const fallback = 'endcrawl-620c2.firebaseapp.com';
  for (final host in [
    'app.lastreel.cookoo.dev',
    'endcrawl-620c2.web.app',
    'endcrawl-620c2.firebaseapp.com',
  ]) {
    test(
      'redirect helper stays on $host despite a different build override',
      () {
        expect(firebaseAuthDomain(host, fallback: fallback), host);
      },
    );
  }
  test('local and unrecognized hosts keep the configured fallback', () {
    for (final host in [
      '',
      'localhost',
      'untrusted.example',
      'app.lastreel.cookoo.dev.untrusted.example',
    ]) {
      expect(firebaseAuthDomain(host, fallback: fallback), fallback);
    }
  });
}
