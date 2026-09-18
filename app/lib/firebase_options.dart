// PLACEHOLDER — not the generated file.
//
// `flutterfire configure --project=endcrawl-620c2` registers the iOS and
// Android apps with the Firebase project and overwrites this file with the
// real `DefaultFirebaseOptions`. It has not been run yet, because it needs
// an interactive Firebase login.
//
// This placeholder exists so the project still analyses and tests cleanly
// before that step. It deliberately throws rather than carrying invented
// keys: a config that looks real but isn't would fail later, somewhere less
// obvious, with a worse error.
//
// See app/README.md → "Firebase setup" for the full sequence.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured yet.\n'
      '\n'
      'Run, from the app/ directory:\n'
      '  dart pub global activate flutterfire_cli\n'
      '  flutterfire configure --project=endcrawl-620c2\n'
      '\n'
      'That registers the iOS and Android apps and replaces '
      'lib/firebase_options.dart with the generated configuration.',
    );
  }
}
