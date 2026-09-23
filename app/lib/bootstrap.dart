import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/external_links.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/firebase_auth_repository.dart';
import 'data/repositories/firestore_project_repository.dart';
import 'data/repositories/project_repository.dart';
import 'data/repositories/user_profile_repository.dart';
import 'data/sources/session_store.dart';
import 'domain/models/app_user.dart';
import 'domain/models/user_profile.dart';
import 'firebase_options.dart';

/// The app's dependency-injection seams.
///
/// Screens and controllers only ever read the providers below; which
/// implementation backs each one is decided here and by the [AppServices]
/// that [bootstrap] hands `main`, and tests replace them wholesale with fakes.

/// Platform services, seeded at startup so nothing has to resolve them async.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  throw StateError('firebaseAuthProvider was not overridden — see bootstrap().');
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  throw StateError('firestoreProvider was not overridden — see bootstrap().');
});

final sessionStoreProvider = Provider<SessionStore>((ref) {
  throw StateError('sessionStoreProvider was not overridden — see bootstrap().');
});

/// "Now", injectable so cooldowns and relative times are testable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Leaving the app — Mail, links, the App Store. Overridden in tests.
final externalLinksProvider = Provider<ExternalLinks>((ref) => const UrlLauncherLinks());

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
final userProfileRepositoryForProvider = Provider.family<UserProfileRepository, String>((ref, uid) {
  return FirestoreUserProfileRepository(ref.watch(firestoreProvider), uid: uid);
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

/// The platform services `main` seeds the root `ProviderScope` with.
class AppServices {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final SessionStore sessionStore;

  const AppServices({required this.auth, required this.firestore, required this.sessionStore});
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
  );
}
