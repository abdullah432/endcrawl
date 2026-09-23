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
    if (clean.isEmpty) return Future.value(const Err(AppFailure(FailureKind.unknown, 'Enter your name.')));
    return _ref.read(authRepositoryProvider).updateDisplayName(clean);
  }

  Future<Result<AppUser>> connect(SignInMethod method, {String? email, String? password}) {
    final auth = _ref.read(authRepositoryProvider);
    return switch (method) {
      SignInMethod.google => auth.linkGoogle(),
      SignInMethod.apple => auth.linkApple(),
      SignInMethod.password => auth.linkPassword(email: email ?? '', password: password ?? ''),
    };
  }

  Future<Result<AppUser>> disconnect(SignInMethod method) => _ref.read(authRepositoryProvider).unlink(method);

  /// Deletes the account for good, in the only safe order.
  ///
  /// Re-authenticates first, so the one step that demands a recent sign-in
  /// can't fail after the data is already gone. Then the projects and the
  /// profile, while the security rules still recognise the owner, then the
  /// sign-in itself. Any failure stops there, leaving the account usable.
  Future<Result<void>> deleteAccount({String? password}) async {
    final auth = _ref.read(authRepositoryProvider);
    final projects = _ref.read(projectRepositoryProvider);

    if (await auth.reauthenticate(password: password) case Err(:final failure)) return Err(failure);

    switch (await projects.listSummaries()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        for (final summary in value) {
          if (await projects.delete(summary.id) case Err(:final failure)) return Err(failure);
        }
    }
    if (await _ref.read(userProfileRepositoryProvider).delete() case Err(:final failure)) return Err(failure);

    final session = _ref.read(sessionStoreProvider);
    await session.setLeftOpen(null);
    await session.setLastOpened(null);

    return auth.deleteCurrentUser();
  }
}

final accountControllerProvider = Provider<AccountController>(AccountController.new);
