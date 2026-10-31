import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/bootstrap.dart';
import 'package:lastreel/core/services/clarity.dart';
import 'package:lastreel/domain/models/app_user.dart';

import '../support/fake_auth_repository.dart';

void main() {
  test('Clarity.setCustomUserId accepts a valid Firebase UID', () {
    expect(
      Clarity.setCustomUserId('OEaoOTXUxBZhrEfaovNxtZlIpzT2'),
      isTrue,
    );
    expect(Clarity.setCustomUserId('   '), isFalse);
  });

  test('clarityUserSyncProvider links uid on sign-in and clears on sign-out', () async {
    final recorded = <String?>[];
    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        clarityUserIdSetterProvider.overrideWithValue((uid) {
          recorded.add(uid);
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(clarityUserSyncProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(authStateProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(recorded, isEmpty);

    await auth.signInWithGoogle();
    await Future<void>.delayed(Duration.zero);
    expect(recorded, [testUser.uid]);

    // Updating display name keeps the same uid and should not re-emit.
    await auth.updateDisplayName('Updated Name');
    await Future<void>.delayed(Duration.zero);
    expect(recorded, [testUser.uid]);

    await auth.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(recorded, [testUser.uid, null]);

    await auth.signInWithEmail(
      email: 'second@example.com',
      password: 'password123',
    );
    await Future<void>.delayed(Duration.zero);
    expect(recorded, [testUser.uid, null, 'test-uid']);
  });

  test('clarityUserSyncProvider links initial signed-in user on startup', () async {
    final recorded = <String?>[];
    const initial = AppUser(
      uid: 'OEaoOTXUxBZhrEfaovNxtZlIpzT2',
      email: 'daddylovesyou0506@gmail.com',
      isEmailVerified: true,
      methods: {SignInMethod.google},
    );
    final auth = FakeAuthRepository(initialUser: initial);
    addTearDown(auth.dispose);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        clarityUserIdSetterProvider.overrideWithValue((uid) {
          recorded.add(uid);
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(clarityUserSyncProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(authStateProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(recorded, ['OEaoOTXUxBZhrEfaovNxtZlIpzT2']);
  });
}
