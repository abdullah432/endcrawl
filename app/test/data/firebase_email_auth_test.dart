import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/result.dart';
import 'package:lastreel/data/repositories/firebase_auth_repository.dart';

class _KeychainFailureAuth extends Fake implements FirebaseAuth {
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => throw FirebaseAuthException(code: 'keychain-error');

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async => throw FirebaseAuthException(code: 'keychain-error');
}

void main() {
  test('email login and signup explain Keychain failure as a build issue', () async {
    final repository = FirebaseAuthRepository(auth: _KeychainFailureAuth());
    final results = [
      await repository.signInWithEmail(
        email: 'tester@example.com',
        password: 'test-password-1',
      ),
      await repository.registerWithEmail(
        name: 'Tester',
        email: 'tester@example.com',
        password: 'test-password-1',
      ),
    ];

    for (final result in results) {
      final failure = result.failureOrNull!;
      expect(failure.kind, FailureKind.permission);
      expect(failure.field, isNull);
      expect(failure.message, contains('Keychain access'));
      expect(failure.message, contains('correctly signed build'));
      expect((failure.cause as FirebaseAuthException).code, 'keychain-error');
    }
  });
}
