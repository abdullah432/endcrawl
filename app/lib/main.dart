import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase, Firestore's cache settings and platform storage are all
  // resolved before the first frame, so no screen has to render a loading
  // state just to find out where its data lives.
  final services = await bootstrap();

  runApp(
    ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(services.auth),
        firestoreProvider.overrideWithValue(services.firestore),
        sessionStoreProvider.overrideWithValue(services.sessionStore),
      ],
      child: const EndcrawlApp(),
    ),
  );
}

class EndcrawlApp extends StatelessWidget {
  const EndcrawlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: MaterialApp(
        title: 'EndCrawl',
        debugShowCheckedModeBanner: false,
        theme: buildEndcrawlTheme(),
        home: const AuthGate(),
      ),
    );
  }
}
