import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/result.dart';
import '../../domain/models/app_user.dart';
import 'auth_repository.dart';

/// Firebase Authentication implementation: email/password plus Google.
///
/// Every `FirebaseAuthException` is translated into an [AppFailure] carrying
/// a message written for the person reading it, so error codes never reach
/// the UI layer.
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  /// Set once [GoogleSignIn.initialize] has completed. 7.x requires it before
  /// any other call, and it only needs to happen once per process.
  Future<void>? _googleInitialization;

  FirebaseAuthRepository({FirebaseAuth? auth, GoogleSignIn? google})
      : _auth = auth ?? FirebaseAuth.instance,
        _google = google ?? GoogleSignIn.instance;

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_toAppUser);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<Result<AppUser>> signInWithEmail({required String email, required String password}) {
    return _guard(() async {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _requireUser(credential.user);
    });
  }

  @override
  Future<Result<AppUser>> registerWithEmail({required String email, required String password}) {
    return _guard(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _requireUser(credential.user);
    });
  }

  @override
  Future<Result<AppUser>> signInWithGoogle() {
    return _guard(() async {
      // No clientId/serverClientId is passed: the plugin resolves both from
      // the config files `flutterfire configure` writes — google-services.json
      // on Android, GoogleService-Info.plist on iOS. Hard-coding them here
      // would mean a second place to update every time the Firebase project
      // changes, and would put OAuth client ids in source control.
      await (_googleInitialization ??= _google.initialize());

      // 7.x: authenticate() returns a non-null account or throws — a user
      // backing out arrives as GoogleSignInException(code: canceled), not
      // as a null account the way the 6.x signIn() API worked.
      final account = await _google.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      return _requireUser(result.user);
    });
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) {
    return _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));
  }

  @override
  Future<Result<void>> signOut() {
    return _guard(() async {
      // Signing out of Firebase alone would leave the Google session cached,
      // so the next sign-in would silently reuse the same account instead of
      // letting the user choose one.
      if (_googleInitialization != null) {
        await _google.signOut();
      }
      await _auth.signOut();
    });
  }

  AppUser _requireUser(User? user) {
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found', message: 'No account was returned.');
    }
    return _toAppUser(user)!;
  }

  AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isEmailVerified: user.emailVerified,
    );
  }

  Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Ok(await body());
    } on FirebaseAuthException catch (e, s) {
      return Err(_mapAuthException(e, s));
    } on GoogleSignInException catch (e, s) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const Err(cancelledByUser);
      }
      return Err(AppFailure(
        e.code == GoogleSignInExceptionCode.clientConfigurationError ||
                e.code == GoogleSignInExceptionCode.providerConfigurationError
            ? FailureKind.permission
            : FailureKind.network,
        'Google Sign-In is unavailable right now.',
        cause: e,
        stackTrace: s,
      ));
    } on Object catch (e, s) {
      return Err(AppFailure(FailureKind.unknown, 'Something went wrong. Try again.', cause: e, stackTrace: s));
    }
  }

  AppFailure _mapAuthException(FirebaseAuthException e, StackTrace s) {
    final (kind, message) = switch (e.code) {
      'invalid-email' => (FailureKind.unknown, 'That email address is not valid.'),
      'user-disabled' => (FailureKind.permission, 'This account has been disabled.'),
      // Firebase deliberately returns one code for wrong-password and
      // no-such-user so an attacker can't enumerate accounts; the message
      // has to stay equally vague.
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        (FailureKind.permission, 'That email or password is not right.'),
      'email-already-in-use' => (FailureKind.unknown, 'An account already exists for that email.'),
      'weak-password' => (FailureKind.unknown, 'Pick a password of at least 6 characters.'),
      'operation-not-allowed' => (
          FailureKind.permission,
          'That sign-in method is not enabled for this project.',
        ),
      'too-many-requests' => (FailureKind.permission, 'Too many attempts. Try again in a few minutes.'),
      'network-request-failed' => (FailureKind.network, 'No connection. Check your network and try again.'),
      'account-exists-with-different-credential' => (
          FailureKind.permission,
          'That email is already registered with a different sign-in method.',
        ),
      _ => (FailureKind.unknown, 'Could not sign you in. Try again.'),
    };
    return AppFailure(kind, message, cause: e, stackTrace: s);
  }
}
