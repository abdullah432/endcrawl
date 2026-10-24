import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/result.dart';
import 'package:lastreel/data/repositories/firebase_auth_repository.dart';
import 'package:lastreel/domain/models/app_user.dart';

class _Provider extends Fake implements UserInfo {
  @override
  String get providerId => 'google.com';
}

class _User extends Fake implements User {
  @override
  String get uid => 'pilot';
  @override
  String get email => 'abdullah234ktk@gmail.com';
  @override
  String get displayName => 'Abdullah';
  @override
  String? get photoURL => null;
  @override
  bool get emailVerified => true;
  @override
  List<UserInfo> get providerData => [_Provider()];
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? currentUser;
  AuthProvider? redirectedWith;
  FirebaseAuthException? failure;
  bool completeRedirect = true;

  @override
  Future<void> signInWithRedirect(AuthProvider provider) async {
    redirectedWith = provider;
    if (failure case final error?) throw error;
    if (completeRedirect) currentUser = _User();
  }

  @override
  Stream<User?> userChanges() => Stream.value(currentUser);

  @override
  Future<UserCredential> signInWithPopup(AuthProvider provider) =>
      throw StateError('Web Google sign-in must not depend on popup windows.');
}

void main() {
  test('web Google login redirects and retains provider account selection', () async {
    final firebase = _Auth();
    final repository = FirebaseAuthRepository(auth: firebase, isWeb: true);
    final result = await repository.signInWithGoogle();
    expect(result, isA<Ok<AppUser>>());
    expect(firebase.redirectedWith, isA<GoogleAuthProvider>());
    expect((firebase.redirectedWith! as GoogleAuthProvider).parameters['prompt'], 'select_account');
    expect(result.valueOrNull?.email, 'abdullah234ktk@gmail.com');
  });

  test('a restored redirect session reaches the existing user stream', () async {
    final firebase = _Auth()..currentUser = _User();
    final repository = FirebaseAuthRepository(auth: firebase, isWeb: true);
    final user = await repository.userChanges().first;
    expect(user?.uid, 'pilot');
    expect(user?.methods, {SignInMethod.google});
    expect(user?.isEmailVerified, true);
  });

  test('redirect failures preserve the existing account and surface a handled error', () async {
    final firebase = _Auth()
      ..currentUser = _User()
      ..failure = FirebaseAuthException(code: 'network-request-failed');
    final repository = FirebaseAuthRepository(auth: firebase, isWeb: true);
    final result = await repository.signInWithGoogle();
    expect(result.failureOrNull?.kind, FailureKind.network);
    expect(repository.currentUser?.uid, 'pilot');
  });

  test('returning without navigation or a user never fabricates an account', () async {
    final firebase = _Auth()..completeRedirect = false;
    final repository = FirebaseAuthRepository(auth: firebase, isWeb: true);
    expect(await repository.signInWithGoogle(), isA<Err<AppUser>>());
    expect(repository.currentUser, null);
  });
}
