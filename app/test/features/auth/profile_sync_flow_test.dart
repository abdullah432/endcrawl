import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/result.dart';
import 'package:lastreel/core/services/profile_sync.dart';
import 'package:lastreel/features/auth/controllers/auth_controller.dart';
import 'package:lastreel/features/auth/widgets/auth_gate.dart';
import 'package:lastreel/features/library/screens/library_screen.dart';
import 'package:lastreel/features/settings/controllers/account_controller.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

class _Client implements ProfileSyncClient {
  int syncs = 0;
  Completer<ProfileSyncStatus>? pending;
  final deletionStates = <bool>[];
  @override
  Future<ProfileSyncStatus> ensure(String uid) async {
    syncs++;
    return pending == null ? ProfileSyncStatus.synced : await pending!.future;
  }

  @override
  Future<void> setDeletionState(String uid, {required bool suspended}) async {
    deletionStates.add(suspended);
  }
}

void main() {
  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(AuthGate)));

  for (final provider in ['email', 'google', 'apple']) {
    testWidgets('$provider sign-in reaches the root background synchronizer', (
      tester,
    ) async {
      final client = _Client();
      final sync = ProfileSync(
        client: client,
        enabledFor: (uid) => uid == 'test-uid',
      );
      addTearDown(sync.dispose);
      final app = AppHarness(auth: FakeAuthRepository(), profileSync: sync);
      await app.pump(tester);
      switch (provider) {
        case 'email':
          await app.auth.signInWithEmail(
            email: 'abdullah234ktk@gmail.com',
            password: 'password1',
          );
        case 'google':
          await app.auth.signInWithGoogle();
        case 'apple':
          await app.auth.signInWithApple();
      }
      await tester.pumpAndSettle();
      expect(client.syncs, 1);
      expect(find.byType(LibraryScreen), findsOneWidget);
    });
  }

  for (final optedIn in [false, true]) {
    testWidgets('pilot signup explicitly stores marketing choice $optedIn', (
      tester,
    ) async {
      final client = _Client();
      final sync = ProfileSync(
        client: client,
        enabledFor: (uid) => uid == 'test-uid',
      );
      addTearDown(sync.dispose);
      final app = AppHarness(auth: FakeAuthRepository(), profileSync: sync);
      await app.pump(tester);
      await container(tester)
          .read(authControllerProvider.notifier)
          .createAccount(
            name: 'Abdullah',
            email: 'abdullah234ktk@gmail.com',
            password: 'password1',
            marketingOptIn: optedIn,
          );
      await tester.pumpAndSettle();
      expect(app.profile.saves, 1);
      expect(app.profile.profile.marketingOptIn, optedIn);
      expect(client.syncs, greaterThanOrEqualTo(1));
      expect(app.auth.currentUser?.displayName, 'Abdullah');
    });
  }

  testWidgets(
    'a restored session works while synchronization is still pending',
    (tester) async {
      final client = _Client()..pending = Completer<ProfileSyncStatus>();
      final sync = ProfileSync(client: client, enabledFor: (_) => true);
      addTearDown(sync.dispose);
      final app = AppHarness(
        profileSync: sync,
        projects: FakeProjectRepository(seed: [film()]),
      );
      await app.pump(tester);
      expect(client.syncs, 1);
      expect(find.byType(LibraryScreen), findsOneWidget);
      expect(app.auth.currentUser, isNotNull);
      client.pending!.completeError(StateError('offline'));
      await tester.pump();
      // The library remains accessible after a failed repair as well.
      expect(find.byType(LibraryScreen), findsOneWidget);
      sync.dispose();
    },
  );

  testWidgets(
    'account deletion drains background work before deleting user data',
    (tester) async {
      final client = _Client()..pending = Completer<ProfileSyncStatus>();
      final sync = ProfileSync(client: client, enabledFor: (_) => true);
      addTearDown(sync.dispose);
      final app = AppHarness(
        profileSync: sync,
        projects: FakeProjectRepository(seed: [film()]),
      );
      await app.pump(tester);
      final deletion = container(
        tester,
      ).read(accountControllerProvider).deleteAccount();
      await tester.pump();
      expect(app.profile.deleted, false);
      expect(client.deletionStates, isEmpty);
      client.pending!.complete(ProfileSyncStatus.synced);
      await tester.pumpAndSettle();
      expect((await deletion).isOk, true);
      expect(client.deletionStates, [true]);
      expect(app.profile.deleted, true);
      expect(app.auth.deleted, true);
    },
  );

  testWidgets('failed deletion resumes repair and preserves the account', (
    tester,
  ) async {
    final client = _Client();
    final sync = ProfileSync(client: client, enabledFor: (_) => true);
    addTearDown(sync.dispose);
    final auth = FakeAuthRepository(initialUser: testUser)
      ..prepareDeletionFailure = const AppFailure(
        FailureKind.network,
        'Try again',
      );
    final app = AppHarness(
      auth: auth,
      profileSync: sync,
      projects: FakeProjectRepository(seed: [film()]),
    );
    await app.pump(tester);
    final result = await container(
      tester,
    ).read(accountControllerProvider).deleteAccount();
    await tester.pumpAndSettle();
    expect(result.isOk, false);
    expect(client.deletionStates, [true, false]);
    expect(app.profile.deleted, false);
    expect(app.auth.deleted, false);
    expect(app.auth.currentUser, isNotNull);
  });

  testWidgets(
    'use a different email removes a pilot profile under the deletion guard',
    (tester) async {
      final client = _Client();
      final sync = ProfileSync(client: client, enabledFor: (_) => true);
      addTearDown(sync.dispose);
      final app = AppHarness(auth: FakeAuthRepository(), profileSync: sync);
      await app.pump(tester);
      final controller = container(
        tester,
      ).read(authControllerProvider.notifier);
      await controller.createAccount(
        name: 'Abdullah',
        email: 'abdullah234ktk@gmail.com',
        password: 'password1',
        marketingOptIn: false,
      );
      await tester.pumpAndSettle();
      await controller.useDifferentEmail();
      await tester.pumpAndSettle();
      expect(app.auth.deleted, true);
      expect(app.profile.deleted, true);
      expect(client.deletionStates, [true]);
    },
  );
}
