import '../../core/result.dart';
import '../../domain/models/app_user.dart';

/// The seam between the app and the identity provider.
///
/// Mirrors [ProjectRepository]'s shape deliberately: failures come back as
/// [AppFailure] with a message already fit to show a user, so no screen ever
/// has to know what a `FirebaseAuthException` code means.
abstract interface class AuthRepository {
  /// Emits on sign-in, sign-out, and token refresh. The first event is the
  /// restored session (or null), which is what the auth gate waits for.
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<Result<AppUser>> signInWithEmail({required String email, required String password});

  Future<Result<AppUser>> registerWithEmail({required String email, required String password});

  Future<Result<AppUser>> signInWithGoogle();

  Future<Result<void>> sendPasswordResetEmail(String email);

  Future<Result<void>> signOut();
}

/// Raised through [Result] when the user backs out of a provider flow.
///
/// Distinct from a real failure so the UI can stay silent instead of showing
/// an error for something the user did on purpose.
const cancelledByUser = AppFailure(FailureKind.unknown, 'Sign-in cancelled.');

bool isCancellation(AppFailure failure) => identical(failure, cancelledByUser);
