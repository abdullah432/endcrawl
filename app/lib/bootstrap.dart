import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/analytics.dart';
import 'core/services/external_links.dart';
import 'core/config/billing_config.dart';
import 'data/repositories/revenuecat_entitlement_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/entitlement_repository.dart';
import 'data/repositories/web_entitlement_repository.dart';
import 'data/repositories/firebase_auth_repository.dart';
import 'data/repositories/firestore_project_repository.dart';
import 'data/repositories/project_repository.dart';
import 'data/repositories/user_profile_repository.dart';
import 'data/sources/session_store.dart';
import 'domain/models/app_user.dart';
import 'domain/models/entitlement.dart';
import 'domain/models/user_profile.dart';
import 'features/cookoo/data/cookoo_store.dart';
import 'features/review/review_prompt_store.dart';
import 'firebase_options.dart';

/// The app's dependency-injection seams.
///
/// Screens and controllers only ever read the providers below; which
/// implementation backs each one is decided here and by the [AppServices]
/// that [bootstrap] hands `main`, and tests replace them wholesale with fakes.

/// Platform services, seeded at startup so nothing has to resolve them async.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  throw StateError(
    'firebaseAuthProvider was not overridden — see bootstrap().',
  );
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  throw StateError('firestoreProvider was not overridden — see bootstrap().');
});

final sessionStoreProvider = Provider<SessionStore>((ref) {
  throw StateError(
    'sessionStoreProvider was not overridden — see bootstrap().',
  );
});

/// "Now", injectable so cooldowns and relative times are testable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Leaving the app — Mail, links, the App Store. Overridden in tests.
final externalLinksProvider = Provider<ExternalLinks>(
  (ref) => const UrlLauncherLinks(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(auth: ref.watch(firebaseAuthProvider));
});

/// The signed-in account, or null. Everything downstream keys off this.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).userChanges();
});

/// Just the signed-in uid. Data repositories watch this rather than the
/// whole user, so renaming or verifying an account doesn't tear down and
/// rebuild every repository (and reload the library) for nothing.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider.select((state) => state.value?.uid));
});

/// Project storage, scoped to whoever is signed in.
///
/// Rebuilt whenever the account changes, so one user's projects can never be
/// served to the next — the uid is baked into the repository's document path
/// rather than being passed per call and possibly forgotten.
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const SignedOutProjectRepository();
  return FirestoreProjectRepository(ref.watch(firestoreProvider), uid: uid);
});

/// The profile store for a given account. A family so a flow that has just
/// created an account can write to it before the auth stream has caught up.
final userProfileRepositoryForProvider =
    Provider.family<UserProfileRepository, String>((ref, uid) {
      return FirestoreUserProfileRepository(
        ref.watch(firestoreProvider),
        uid: uid,
      );
    });

/// The signed-in account's profile store.
final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const SignedOutUserProfileRepository();
  return ref.watch(userProfileRepositoryForProvider(uid));
});

final userProfileProvider = StreamProvider<UserProfile>((ref) {
  return ref.watch(userProfileRepositoryProvider).watch();
});

/// Google Analytics. Overridden in tests.
final analyticsProvider = Provider<AppAnalytics>(
  (ref) => const FirebaseAppAnalytics(),
);

/// Applies the account's "Usage analytics" choice to Google Analytics
/// whenever it changes. Watched from the app root; signed out, the profile
/// is the default one, so collection stays on.
final analyticsPreferenceSyncProvider = Provider<void>((ref) {
  ref.listen(
    userProfileProvider.select(
      (profile) => profile.value?.preferences.usageAnalytics,
    ),
    (_, enabled) {
      if (enabled != null) {
        ref.read(analyticsProvider).setCollectionEnabled(enabled);
      }
    },
    fireImmediately: true,
  );
});

/// One SDK owner for the lifetime of the app, with immediate account isolation.
final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  if (kIsWeb) {
    final uid = ref.watch(currentUidProvider);
    if (uid == null) return const FreeEntitlementRepository();
    final repository = WebEntitlementRepository(
      uid: uid,
      firestore: ref.watch(firestoreProvider),
      functions: FirebaseFunctions.instance,
    );
    ref.onDispose(repository.dispose);
    return repository;
  }
  if (BillingConfig.apiKey.isEmpty) return const FreeEntitlementRepository();
  final repository = RevenueCatEntitlementRepository(
    apiKey: BillingConfig.apiKey,
  );
  ref.listen(
    currentUidProvider,
    (_, uid) => repository.setUser(uid),
    fireImmediately: true,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// The signed-in account's plan. Defaults to Free while loading, so a slow
/// store never makes the cap disappear.
final entitlementProvider = StreamProvider<Entitlement>((ref) {
  ref.watch(currentUidProvider);
  return ref.watch(entitlementRepositoryProvider).watch();
});

/// The platform services `main` seeds the root `ProviderScope` with.
class AppServices {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final SessionStore sessionStore;
  final CookooStore cookooStore;
  final ReviewPromptStore reviewPromptStore;

  const AppServices({
    required this.auth,
    required this.firestore,
    required this.sessionStore,
    required this.cookooStore,
    required this.reviewPromptStore,
  });
}

/// Initialises Firebase and resolves the platform services. Called before
/// `runApp`, so the first frame already has everything it needs.
Future<AppServices> bootstrap() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline persistence is on by default on iOS and Android; it is set
  // explicitly here because this app depends on it — the brief's users are
  // on set, and an unbounded cache means a large project set never gets
  // evicted out from under them mid-edit.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final preferences = await SharedPreferences.getInstance();

  return AppServices(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    sessionStore: PreferencesSessionStore(preferences),
    cookooStore: PreferencesCookooStore(preferences),
    reviewPromptStore: PreferencesReviewPromptStore(preferences),
  );
}
