import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/models/app_user.dart';

enum ProfileSyncStatus { synced, disabled, suspended }

abstract interface class ProfileSyncClient {
  Future<ProfileSyncStatus> ensure(String uid);
  Future<void> setDeletionState(String uid, {required bool suspended});
}

class FirebaseProfileSyncClient implements ProfileSyncClient {
  final FirebaseFunctions functions;
  final FirebaseAuth auth;
  FirebaseProfileSyncClient(this.functions, this.auth);

  @override
  Future<ProfileSyncStatus> ensure(String uid) async {
    if (auth.currentUser?.uid != uid) return ProfileSyncStatus.disabled;
    final result = await functions.httpsCallable('ensureUserProfile').call();
    return switch ((result.data as Map)['status']) {
      'synced' => ProfileSyncStatus.synced,
      'suspended' => ProfileSyncStatus.suspended,
      _ => ProfileSyncStatus.disabled,
    };
  }

  @override
  Future<void> setDeletionState(String uid, {required bool suspended}) async {
    if (auth.currentUser?.uid != uid) {
      throw StateError('The signed-in account changed.');
    }
    await functions.httpsCallable('setProfileDeletionState').call<void>({
      'suspended': suspended,
    });
  }
}

/// Background synchronization. One request at a time, with coalesced identity
/// updates and account-scoped retries. No auth stream or navigation waits on it.
class ProfileSync {
  final ProfileSyncClient? client;
  final bool Function(String uid) enabledFor;
  final void Function()? onFailure;
  AppUser? _user;
  Future<void>? _flight;
  Timer? _retry;
  bool _pending = false;
  bool _disposed = false;
  final _suspended = <String>{};
  int _delaySeconds = 1;

  ProfileSync({this.client, required this.enabledFor, this.onFailure});

  void userChanged(AppUser? user) {
    final previous = _user;
    _user = user;
    if (previous == user) return;
    _retry?.cancel();
    _delaySeconds = 1;
    _pending = false;
    if (user != null && enabledFor(user.uid)) request();
  }

  void resumed() {
    _delaySeconds = 1;
    request();
  }

  void request() {
    final user = _user;
    if (_disposed ||
        client == null ||
        user == null ||
        !enabledFor(user.uid) ||
        _suspended.contains(user.uid)) {
      return;
    }
    _retry?.cancel();
    _pending = true;
    if (_flight != null) return;
    // Assign the future before its body can complete (also safe for sync fakes).
    _flight = Future<void>.microtask(_flush).whenComplete(() {
      _flight = null;
      if (_pending && !_disposed) request();
    });
  }

  Future<void> _flush() async {
    while (_pending && !_disposed) {
      _pending = false;
      final user = _user;
      if (user == null ||
          !enabledFor(user.uid) ||
          _suspended.contains(user.uid)) {
        return;
      }
      try {
        final status = await client!.ensure(user.uid);
        if (_user != user || _disposed) continue;
        if (status == ProfileSyncStatus.suspended) {
          _schedule(user.uid);
        } else {
          _delaySeconds = 1;
        }
      } on Object {
        if (_user != user || _disposed) continue;
        onFailure?.call();
        _schedule(user.uid);
      }
    }
  }

  void _schedule(String uid) {
    if (_disposed || _suspended.contains(uid) || _user?.uid != uid) return;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: _delaySeconds), request);
    _delaySeconds = (_delaySeconds * 2).clamp(1, 30);
  }

  /// Drain this device, then lock server reconciliation across other devices.
  /// A failure aborts deletion before any user data is removed.
  Future<void> suspend(String uid) async {
    if (!enabledFor(uid) || client == null) return;
    _suspended.add(uid);
    _retry?.cancel();
    _pending = false;
    await _flight;
    await client!.setDeletionState(uid, suspended: true);
  }

  Future<void> resume(String uid) async {
    if (!enabledFor(uid) || client == null) return;
    try {
      await client!.setDeletionState(uid, suspended: false);
    } finally {
      _suspended.remove(uid);
      if (_user?.uid == uid) request();
    }
  }

  void dispose() {
    _disposed = true;
    _pending = false;
    _retry?.cancel();
  }
}
