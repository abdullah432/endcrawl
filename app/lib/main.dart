import 'core/services/clarity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bootstrap.dart';
import 'core/config/orientations.dart';
import 'core/root_navigator.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/ec_toast.dart';
import 'features/ads/widgets/resume_ads.dart';
import 'features/cookoo/controllers/cookoo_contact_controller.dart';
import 'features/cookoo/controllers/cookoo_promo_controller.dart';
import 'features/plan/controllers/trial_analytics.dart';
import 'features/review/review_prompt.dart';
import 'features/auth/widgets/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait everywhere; the editor alone opens up landscape, where turning
  // the phone is how the full-bleed monitor (3.4) is reached.
  await SystemChrome.setPreferredOrientations(appOrientations);

  // Firebase, Firestore's cache settings and platform storage are all
  // resolved before the first frame, so no screen has to render a loading
  // state just to find out where its data lives.
  final services = await bootstrap();

  final clarityConfig = ClarityConfig(
    projectId: "yoywe4jl9e",
    logLevel: LogLevel.None,
  );

  runApp(
    ClarityWidget(
      clarityConfig: clarityConfig,
      app: ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(services.auth),
          firestoreProvider.overrideWithValue(services.firestore),
          sessionStoreProvider.overrideWithValue(services.sessionStore),
          cookooStoreProvider.overrideWithValue(services.cookooStore),
          reviewPromptStoreProvider.overrideWithValue(services.reviewPromptStore),
        ],
        child: const LastReelApp(),
      ),
    ),
  );
}

class LastReelApp extends ConsumerWidget {
  const LastReelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(analyticsPreferenceSyncProvider);
    ref.watch(trialAnalyticsProvider);
    ref.watch(cookooContactSyncProvider);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: MaterialApp(
        title: 'LastReel',
        debugShowCheckedModeBanner: false,
        theme: buildLastReelTheme(),
        navigatorKey: rootNavigatorKey,
        navigatorObservers: [EcToastObserver()],
        builder: (context, child) => ResumeAds(child: ReviewPromptTrigger(child: child!)),
        home: const AuthGate(),
      ),
    );
  }
}
