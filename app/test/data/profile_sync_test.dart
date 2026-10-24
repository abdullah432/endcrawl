import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/services/profile_sync.dart';
import 'package:lastreel/domain/models/app_user.dart';

class TestProfileClient implements ProfileSyncClient {
  final calls = <String>[];
  final deletions = <String>[];
  Future<ProfileSyncStatus> Function(String uid)? handle;
  @override
  Future<ProfileSyncStatus> ensure(String uid) async {
    calls.add(uid);
    return handle == null ? ProfileSyncStatus.synced : await handle!(uid);
  }

  @override
  Future<void> setDeletionState(String uid, {required bool suspended}) async {
    deletions.add('$uid:$suspended');
  }
}

const pilot = AppUser(
  uid: 'pilot',
  email: 'abdullah234ktk@gmail.com',
  displayName: 'Abdullah',
);

void main() {
  testWidgets('default off and pilot exclusion produce no requests', (
    tester,
  ) async {
    final client = TestProfileClient();
    final off = ProfileSync(client: client, enabledFor: (_) => false);
    final sync = ProfileSync(
      client: client,
      enabledFor: (uid) => uid == 'pilot',
    );
    addTearDown(off.dispose);
    addTearDown(sync.dispose);
    off.userChanged(pilot);
    sync.userChanged(const AppUser(uid: 'other'));
    off.resumed();
    sync.resumed();
    await tester.pump();
    expect(client.calls, isEmpty);
  });

  testWidgets(
    'restored sessions, identity changes, and resume trigger synchronization',
    (tester) async {
      final client = TestProfileClient();
      final sync = ProfileSync(client: client, enabledFor: (_) => true);
      addTearDown(sync.dispose);
      sync.userChanged(pilot);
      await tester.pump();
      expect(client.calls, ['pilot']);
      sync.userChanged(pilot);
      await tester.pump();
      expect(client.calls, hasLength(1));
      sync.userChanged(pilot.copyWith(displayName: 'New Name'));
      await tester.pump();
      sync.resumed();
      await tester.pump();
      expect(client.calls, ['pilot', 'pilot', 'pilot']);
    },
  );

  testWidgets('offline retries back off and sign-out cancels scheduled work', (
    tester,
  ) async {
    final client = TestProfileClient()
      ..handle = (_) async => throw StateError('offline');
    final sync = ProfileSync(client: client, enabledFor: (_) => true);
    addTearDown(sync.dispose);
    sync.userChanged(pilot);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(client.calls, hasLength(2));
    await tester.pump(const Duration(seconds: 1));
    expect(client.calls, hasLength(2));
    await tester.pump(const Duration(seconds: 1));
    expect(client.calls, hasLength(3));
    sync.userChanged(null);
    await tester.pump(const Duration(seconds: 30));
    expect(client.calls, hasLength(3));
  });

  testWidgets(
    'in-flight requests coalesce updates and isolate an account switch',
    (tester) async {
      final pending = Completer<ProfileSyncStatus>();
      final client = TestProfileClient()
        ..handle = (uid) => uid == 'pilot'
            ? pending.future
            : Future.value(ProfileSyncStatus.synced);
      final sync = ProfileSync(client: client, enabledFor: (_) => true);
      addTearDown(sync.dispose);
      sync.userChanged(pilot);
      await tester.pump();
      sync.userChanged(pilot.copyWith(displayName: 'Renamed'));
      sync.userChanged(const AppUser(uid: 'other'));
      await tester.pump();
      expect(client.calls, ['pilot']);
      pending.completeError(StateError('late failure'));
      await tester.pump();
      expect(client.calls, ['pilot', 'other']);
      await tester.pump(const Duration(seconds: 30));
      expect(client.calls, ['pilot', 'other']);
    },
  );

  testWidgets(
    'deletion drains work, suspends server repair, and resumes after failure',
    (tester) async {
      final pending = Completer<ProfileSyncStatus>();
      final client = TestProfileClient()..handle = (_) => pending.future;
      final sync = ProfileSync(client: client, enabledFor: (_) => true);
      addTearDown(sync.dispose);
      sync.userChanged(pilot);
      await tester.pump();
      final draining = sync.suspend('pilot');
      sync.resumed();
      await tester.pump();
      expect(client.deletions, isEmpty);
      pending.complete(ProfileSyncStatus.synced);
      await tester.pump();
      await draining;
      expect(client.deletions, ['pilot:true']);
      expect(client.calls, hasLength(1));
      client.handle = null;
      await sync.resume('pilot');
      await tester.pump();
      expect(client.deletions, ['pilot:true', 'pilot:false']);
      expect(client.calls, hasLength(2));
    },
  );

  testWidgets(
    'backend suspension retries, while disabled rollout remains quiet',
    (tester) async {
      final client = TestProfileClient()
        ..handle = (_) async => ProfileSyncStatus.suspended;
      final sync = ProfileSync(client: client, enabledFor: (_) => true);
      addTearDown(sync.dispose);
      sync.userChanged(pilot);
      await tester.pump();
      client.handle = (_) async => ProfileSyncStatus.disabled;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 30));
      expect(client.calls, hasLength(2));
    },
  );
}
