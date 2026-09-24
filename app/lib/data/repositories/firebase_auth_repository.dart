import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/result.dart';
import '../../domain/models/app_user.dart';
import 'auth_repository.dart';

/// Firebase Authentication implementation: email/password, Google and Apple.
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

  // userChanges(), not authStateChanges(): the latter only fires on
  // sign-in/out, so a verified email or a new display name would never
  // reach the UI.
  @override
  Stream<AppUser?> userChanges() => _auth.userChanges().map(_toAppUser);

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
  Future<Result<AppUser>> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user!;
      await user.updateDisplayName(name.trim());
      // Best effort: the account exists either way, and the verify screen
      // offers "Resend link" if this one never arrives.
      try {
        await user.sendEmailVerification();
      } on FirebaseAuthException catch (_) {}
      await user.reload();
      return _requireUser(_auth.currentUser);
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
      // 7.x: authenticate() returns a non-null account or throws — a user
      // backing out arrives as GoogleSignInException(code: canceled), not
      // as a null account the way the 6.x signIn() API worked.
      final result = await _auth.signInWithCredential(await _googleCredential());
      return _requireUser(result.user);
    });
  }

  @override
  Future<Result<AppUser>> signInWithApple() {
    return _guard(() async {
      // Firebase drives Sign in with Apple natively on iOS and through a
      // web flow elsewhere; no extra package is needed.
      final result = await _auth.signInWithProvider(_appleProvider());
      return _requireUser(result.user);
    });
  }

  @override
  Future<Result<void>> sendEmailVerification() {
    return _guard(() async => _auth.currentUser?.sendEmailVerification());
  }

  @override
  Future<Result<AppUser>> reloadUser() {
    return _guard(() async {
      await _auth.currentUser?.reload();
      return _requireUser(_auth.currentUser);
    });
  }

  @override
  Future<Result<void>> updateDisplayName(String name) {
    return _guard(() async {
      await _auth.currentUser?.updateDisplayName(name.trim());
      await _auth.currentUser?.reload();
    });
  }

  @override
  Future<Result<AppUser>> linkGoogle() {
    return _guard(() async {
      final credential = await _googleCredential();
      await _requireFirebaseUser().linkWithCredential(credential);
      return _reloaded();
    });
  }

  @override
  Future<Result<AppUser>> linkApple() {
    return _guard(() async {
      await _requireFirebaseUser().linkWithProvider(_appleProvider());
      return _reloaded();
    });
  }

  @override
  Future<Result<AppUser>> linkPassword({required String email, required String password}) {
    return _guard(() async {
      final credential = EmailAuthProvider.credential(email: email.trim(), password: password);
      await _requireFirebaseUser().linkWithCredential(credential);
      return _reloaded();
    });
  }

  @override
  Future<Result<AppUser>> unlink(SignInMethod method) async {
    final user = currentUser;
    if (user == null || !user.canUnlink(method)) return const Err(lastSignInMethod);
    return _guard(() async {
      await _requireFirebaseUser().unlink(_providerIdFor(method));
      return _reloaded();
    });
  }

  @override
  Future<Result<void>> reauthenticate({String? password}) {
    return _guard(() async {
      final user = _requireFirebaseUser();
      switch (currentUser?.primaryMethod) {
        case SignInMethod.apple:
          await user.reauthenticateWithProvider(_appleProvider());
        case SignInMethod.google:
          await user.reauthenticateWithCredential(await _googleCredential());
        case SignInMethod.password || null:
          await user.reauthenticateWithCredential(
            EmailAuthProvider.credential(email: user.email ?? '', password: password ?? ''),
          );
      }
    });
  }

  Future<AuthCredential> _googleCredential() async {
    await (_googleInitialization ??= _google.initialize());
    final account = await _google.authenticate();
    return GoogleAuthProvider.credential(idToken: account.authentication.idToken);
  }

  AppleAuthProvider _appleProvider() => AppleAuthProvider()
    ..addScope('email')
    ..addScope('name');

  User _requireFirebaseUser() {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'user-not-found', message: 'Signed out.');
    return user;
  }

  Future<AppUser> _reloaded() async {
    await _auth.currentUser?.reload();
    return _requireUser(_auth.currentUser);
  }

  static String _providerIdFor(SignInMethod method) => switch (method) {
        SignInMethod.apple => 'apple.com',
        SignInMethod.google => 'google.com',
        SignInMethod.password => 'password',
      };

  @override
  Future<Result<void>> deleteCurrentUser() {
    return _guard(() async {
      await _auth.currentUser?.delete();
      // A deleted user doesn't reliably reach userChanges() as null on
      // device, which would leave the app showing the account it just
      // deleted. Signing out makes the change certain, and clears the
      // cached Google session with it.
      if (_googleInitialization != null) await _google.signOut();
      await _auth.signOut();
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
      methods: {
        for (final info in user.providerData)
          ?_methodFor(info.providerId),
      },
    );
  }

  static SignInMethod? _methodFor(String providerId) {
    return switch (providerId) {
      'apple.com' => SignInMethod.apple,
      'google.com' => SignInMethod.google,
      'password' => SignInMethod.password,
      _ => null,
    };
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

  /// Codes Firebase uses when the person closed the Apple or web sheet.
  static const _cancelCodes = {
    'canceled',
    'cancelled',
    'web-context-canceled',
    'web-context-cancelled',
    'popup-closed-by-user',
    'user-cancelled',
  };

  AppFailure _mapAuthException(FirebaseAuthException e, StackTrace s) {
    if (_cancelCodes.contains(e.code)) return cancelledByUser;
    final field = switch (e.code) {
      'invalid-email' || 'email-already-in-use' => AuthField.email,
      'invalid-credential' || 'wrong-password' || 'user-not-found' || 'weak-password' => AuthField.password,
      _ => null,
    };
    final (kind, message) = switch (e.code) {
      'invalid-email' => (FailureKind.unknown, 'That email address is not valid.'),
      'user-disabled' => (FailureKind.permission, 'This account has been disabled.'),
      // Firebase deliberately returns one code for wrong-password and
      // no-such-user so an attacker can't enumerate accounts; the message
      // has to stay equally vague.
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        (FailureKind.permission, 'That password doesn’t match this email. Try again or reset it.'),
      'email-already-in-use' => (FailureKind.unknown, 'An account already exists for that email.'),
      'weak-password' => (FailureKind.unknown, 'Pick a longer password: at least 8 characters with a number.'),
      'requires-recent-login' => (FailureKind.permission, 'For your security, sign in again to do that.'),
      'operation-not-allowed' => (
          FailureKind.permission,
          'That sign-in method is not enabled for this project.',
        ),
      'too-many-requests' => (FailureKind.permission, 'Too many attempts. Try again in a few minutes.'),
      'network-request-failed' => (FailureKind.network, 'No connection. Check your network and try again.'),
      'provider-already-linked' => (FailureKind.unknown, 'That method is already connected.'),
      'credential-already-in-use' => (
          FailureKind.permission,
          'That account already belongs to another EndCrawl login.',
        ),
      'user-mismatch' => (FailureKind.permission, 'That isn’t the account you’re signed in with.'),
      'account-exists-with-different-credential' => (
          FailureKind.permission,
          'That email is already registered with a different sign-in method.',
        ),
      _ => (FailureKind.unknown, 'Could not sign you in. Try again.'),
    };
    return AppFailure(kind, message, cause: e, stackTrace: s, field: field);
  }
}
