import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../domain/models/app_user.dart';

/// The account itself (7.2, 7.6): its name, how it signs in, and deleting
/// it with everything in it.
class AccountController {
  final Ref _ref;
  const AccountController(this._ref);

  Future<Result<void>> rename(String name) {
    final clean = name.trim();
    if (clean.isEmpty) {
      return Future.value(
        const Err(AppFailure(FailureKind.unknown, 'Enter your name.')),
      );
    }
    return _ref.read(authRepositoryProvider).updateDisplayName(clean);
  }

  Future<Result<AppUser>> connect(
    SignInMethod method, {
    String? email,
    String? password,
  }) {
    final auth = _ref.read(authRepositoryProvider);
    return switch (method) {
      SignInMethod.google => auth.linkGoogle(),
      SignInMethod.apple => auth.linkApple(),
      SignInMethod.password => auth.linkPassword(
        email: email ?? '',
        password: password ?? '',
      ),
    };
  }

  Future<Result<AppUser>> disconnect(SignInMethod method) =>
      _ref.read(authRepositoryProvider).unlink(method);

  /// Deletes the account for good, in the only safe order.
  ///
  /// Re-authenticates first, so the one step that demands a recent sign-in
  /// can't fail after the data is already gone. Then the projects and the
  /// profile, while the security rules still recognise the owner, then the
  /// sign-in itself. Any failure stops there, leaving the account usable.
  Future<Result<void>> deleteAccount({String? password}) async {
    if (await verifyIdentity(password: password) case Err(:final failure)) {
      return Err(failure);
    }
    return deleteVerified();
  }

  /// The first half of [deleteAccount]: a fresh sign-in with the account's
  /// own method. Firebase refuses a different account ("user-mismatch").
  Future<Result<void>> verifyIdentity({String? password}) =>
      _ref.read(authRepositoryProvider).reauthenticate(password: password);

  /// The second half of [deleteAccount], for right after [verifyIdentity]
  /// succeeded — the 7.6b screen runs the two apart to say which is under way.
  Future<Result<void>> deleteVerified() async {
    final uid = _ref.read(authRepositoryProvider).currentUser?.uid;
    final sync = _ref.read(profileSyncProvider);
    try {
      if (uid != null) await sync.suspend(uid);
      if (_ref.read(authRepositoryProvider).currentUser?.uid != uid) {
        throw StateError('The signed-in account changed.');
      }
      final result = await _deleteVerified();
      if (result is Err && uid != null) {
        await sync.resume(uid).catchError((Object _) {});
      }
      return result;
    } on Object catch (error, stack) {
      if (uid != null) await sync.resume(uid).catchError((Object _) {});
      return Err(
        AppFailure(
          FailureKind.network,
          'Could not prepare account deletion. Try again.',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
  }

  Future<Result<void>> _deleteVerified() async {
    final auth = _ref.read(authRepositoryProvider);
    final projects = _ref.read(projectRepositoryProvider);

    if (await auth.prepareAccountDeletion() case Err(:final failure)) {
      return Err(failure);
    }
    if (await projects.deleteAll() case Err(:final failure)) {
      return Err(failure);
    }
    if (await _ref.read(userProfileRepositoryProvider).delete() case Err(
      :final failure,
    )) {
      return Err(failure);
    }

    final session = _ref.read(sessionStoreProvider);
    await session.setLeftOpen(null);
    await session.setLastOpened(null);

    // Raised before the sign-in goes, so the gate opens on "Account deleted"
    // (7.6c) rather than flashing the welcome screen first. It only shows
    // once the account is actually gone, and is dropped if that fails.
    final deleted = _ref.read(accountDeletedProvider.notifier)..set(true);
    final result = await auth.deleteCurrentUser();
    if (result is Err) deleted.set(false);
    return result;
  }
}

/// True between a successful deletion and "Done" on 7.6c.
final accountDeletedProvider = NotifierProvider<AccountDeleted, bool>(
  AccountDeleted.new,
);

class AccountDeleted extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool deleted) => state = deleted;
}

final accountControllerProvider = Provider<AccountController>(
  AccountController.new,
);
