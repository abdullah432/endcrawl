import '../../core/result.dart';
import '../../domain/models/app_user.dart';

/// The seam between the app and the identity provider.
///
/// Mirrors [ProjectRepository]'s shape deliberately: failures come back as
/// [AppFailure] with a message already fit to show a user, so no screen ever
/// has to know what a `FirebaseAuthException` code means.
abstract interface class AuthRepository {
  /// Emits on sign-in, sign-out, and whenever the signed-in account itself
  /// changes (verified, renamed, a method linked). The first event is the
  /// restored session (or null), which is what the auth gate waits for.
  Stream<AppUser?> userChanges();

  AppUser? get currentUser;

  Future<Result<AppUser>> signInWithEmail({required String email, required String password});

  /// Creates an email/password account, names it, and sends the
  /// verification email.
  Future<Result<AppUser>> registerWithEmail({
    required String name,
    required String email,
    required String password,
  });

  Future<Result<AppUser>> signInWithGoogle();

  Future<Result<AppUser>> signInWithApple();

  Future<Result<void>> sendPasswordResetEmail(String email);

  Future<Result<void>> sendEmailVerification();

  /// Re-reads the account from the provider — how the app learns a
  /// verification link was clicked in Mail.
  Future<Result<AppUser>> reloadUser();

  Future<Result<void>> updateDisplayName(String name);

  /// Adds a sign-in method to the signed-in account (7.2).
  Future<Result<AppUser>> linkGoogle();

  Future<Result<AppUser>> linkApple();

  /// Adds email & password, for devices without Apple or Google.
  Future<Result<AppUser>> linkPassword({required String email, required String password});

  /// Removes a sign-in method. Fails rather than removing the last one.
  Future<Result<AppUser>> unlink(SignInMethod method);

  /// Proves it's still the account holder before a sensitive change —
  /// deleting the account. Uses the account's main method: [password] for
  /// email accounts, the provider's own sheet for Apple and Google.
  Future<Result<void>> reauthenticate({String? password});

  /// Deletes the signed-in auth account only. Callers that own data
  /// elsewhere (projects, profile) delete that first.
  Future<Result<void>> deleteCurrentUser();

  Future<Result<void>> signOut();
}

/// [AppFailure.field] values for the auth forms.
abstract final class AuthField {
  static const name = 'name';
  static const email = 'email';
  static const password = 'password';
}

/// Raised through [Result] when the user backs out of a provider flow.
///
/// Distinct from a real failure so the UI can stay silent instead of showing
/// an error for something the user did on purpose.
const cancelledByUser = AppFailure(FailureKind.unknown, 'Sign-in cancelled.');

bool isCancellation(AppFailure failure) => identical(failure, cancelledByUser);

/// Returned by [AuthRepository.unlink] for the account's only method.
const lastSignInMethod = AppFailure(
  FailureKind.permission,
  'You always need at least one way to sign in, so your only connected method can’t be removed.',
);
