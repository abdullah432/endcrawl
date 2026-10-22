import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/result.dart';
import 'package:lastreel/data/repositories/auth_repository.dart';
import 'package:lastreel/data/repositories/firebase_auth_repository.dart';
import 'package:lastreel/domain/models/app_user.dart';

class _Info extends Fake implements UserInfo {
  @override
  final String providerId;
  _Info(this.providerId);
}

class _Additional extends Fake implements AdditionalUserInfo {
  @override
  final String? authorizationCode;
  _Additional(this.authorizationCode);
}

class _Credential extends Fake implements UserCredential {
  @override
  final User user;
  @override
  final AdditionalUserInfo additionalUserInfo;
  _Credential(this.user, String? code) : additionalUserInfo = _Additional(code);
}

class _User extends Fake implements User {
  @override
  String uid = 'apple-user';
  @override
  String? email = 'private@privaterelay.appleid.com';
  @override
  String? displayName = 'Private User';
  @override
  String? get photoURL => null;
  @override
  bool get emailVerified => true;
  final providers = ['apple.com'];
  @override
  List<UserInfo> get providerData => providers.map(_Info.new).toList();
  String? code = 'fresh-test-code';
  FirebaseAuthException? reauthError;
  final events = <String>[];
  @override
  Future<UserCredential> reauthenticateWithProvider(
    AuthProvider provider,
  ) async {
    events.add('reauthenticate');
    if (reauthError case final error?) throw error;
    return _Credential(this, code);
  }

  @override
  Future<UserCredential> linkWithProvider(AuthProvider provider) async {
    events.add('link');
    if (!providers.contains(provider.providerId)) {
      providers.add(provider.providerId);
    }
    return _Credential(this, code);
  }

  @override
  Future<User> unlink(String providerId) async {
    events.add('unlink');
    providers.remove(providerId);
    return this;
  }

  @override
  Future<void> reload() async {}
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User? currentUser;
  AuthProvider? requested;
  FirebaseAuthException? revokeError;
  final revokedCodes = <String>[];
  _Auth(this.currentUser);
  @override
  Future<UserCredential> signInWithProvider(AuthProvider provider) async {
    requested = provider;
    return _Credential(currentUser!, 'signin-code');
  }

  @override
  Future<void> revokeTokenWithAuthorizationCode(String code) async {
    (currentUser as _User).events.add('revoke');
    if (revokeError case final error?) throw error;
    revokedCodes.add(code);
  }

  @override
  Future<void> signOut() async => currentUser = null;
}

void main() {
  late _User user;
  late _Auth firebase;
  late FirebaseAuthRepository auth;
  setUp(() {
    user = _User();
    firebase = _Auth(user);
    auth = FirebaseAuthRepository(auth: firebase);
  });

  test(
    'native Apple sign-in requests only name/email and preserves relay identity',
    () async {
      final result = await auth.signInWithApple();
      expect(result, isA<Ok<AppUser>>());
      expect(firebase.requested, isA<AppleAuthProvider>());
      expect((firebase.requested! as AppleAuthProvider).scopes, [
        'email',
        'name',
      ]);
      expect(auth.currentUser?.email, user.email);
      expect(auth.currentUser?.methods, {SignInMethod.apple});
      expect(auth.currentUser?.needsEmailVerification, isFalse);
      expect(firebase.revokedCodes, isEmpty);
    },
  );

  test(
    'Apple deletion revokes a fresh code before data cleanup is allowed',
    () async {
      expect(await auth.reauthenticate(), isA<Ok<void>>());
      expect(await auth.prepareAccountDeletion(), isA<Ok<void>>());
      expect(firebase.revokedCodes, ['fresh-test-code']);
      expect(user.events, ['reauthenticate', 'revoke']);
      // Codes cannot be reused by another deletion attempt.
      expect(await auth.prepareAccountDeletion(), isA<Err<void>>());
    },
  );

  test(
    'cancelled Apple reauthentication is silent and cannot prepare deletion',
    () async {
      user.reauthError = FirebaseAuthException(code: 'canceled');
      final result = await auth.reauthenticate();
      expect((result as Err).failure, same(cancelledByUser));
      expect(await auth.prepareAccountDeletion(), isA<Err<void>>());
      expect(firebase.revokedCodes, isEmpty);
    },
  );

  test(
    'missing code, different account and revocation outage fail closed',
    () async {
      user.code = null;
      await auth.reauthenticate();
      expect(await auth.prepareAccountDeletion(), isA<Err<void>>());
      user.code = 'new-code';
      await auth.reauthenticate();
      user.uid = 'different-account';
      expect(await auth.prepareAccountDeletion(), isA<Err<void>>());
      expect(firebase.revokedCodes, isEmpty);
      await auth.reauthenticate();
      firebase.revokeError = FirebaseAuthException(
        code: 'network-request-failed',
      );
      expect(await auth.prepareAccountDeletion(), isA<Err<void>>());
    },
  );

  test('the final sign-in method cannot be unlinked', () async {
    final result = await auth.unlink(SignInMethod.apple);
    expect((result as Err).failure, same(lastSignInMethod));
    expect(user.events, isEmpty);
  });

  test(
    'disconnecting Apple reauthenticates and revokes before unlink',
    () async {
      user.providers.add('google.com');
      expect(await auth.unlink(SignInMethod.apple), isA<Ok<AppUser>>());
      expect(user.events, ['reauthenticate', 'revoke', 'unlink']);
      expect(auth.currentUser?.methods, {SignInMethod.google});
    },
  );

  test('a revocation failure keeps Apple connected', () async {
    user.providers.add('google.com');
    firebase.revokeError = FirebaseAuthException(
      code: 'network-request-failed',
    );
    expect(await auth.unlink(SignInMethod.apple), isA<Err<AppUser>>());
    expect(user.events, ['reauthenticate', 'revoke']);
    expect(auth.currentUser?.methods, contains(SignInMethod.apple));
  });

  test('password accounts do not need an Apple grant', () async {
    user.providers
      ..clear()
      ..add('password');
    expect(await auth.prepareAccountDeletion(), isA<Ok<void>>());
    expect(firebase.revokedCodes, isEmpty);
  });
}
