import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../data/repositories/auth_repository.dart';

/// Shared form state for the welcome screen and the three credential
/// screens behind it.
///
/// There is deliberately no "mode" here. Signing in, creating an account and
/// resetting a password are separate screens, so nothing has to remember
/// which one the user meant — the screen they are on *is* the answer, and a
/// button label can never disagree with the action it triggers.
class AuthFormState {
  final bool busy;

  /// Set when an attempt failed. Cancellations never land here — backing out
  /// of the Google sheet is not an error worth showing anyone.
  final AppFailure? failure;

  /// The address a reset link was just requested for. Non-null flips the
  /// forgot-password screen to its confirmation state.
  final String? resetRequestedFor;

  const AuthFormState({this.busy = false, this.failure, this.resetRequestedFor});

  AuthFormState copyWith({bool? busy, AppFailure? failure, String? resetRequestedFor}) {
    return AuthFormState(
      busy: busy ?? this.busy,
      failure: failure ?? this.failure,
      resetRequestedFor: resetRequestedFor ?? this.resetRequestedFor,
    );
  }
}

/// Drives the auth screens. Deliberately owns no notion of *who* is signed
/// in — that is `authStateProvider`, fed by the provider's own stream, so
/// there is one source of truth for session state and this only handles the
/// form around it.
class AuthController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Resets everything the previous screen may have left behind.
  ///
  /// All four screens share this one controller, so without it a failure
  /// raised while creating an account would still be on display after
  /// navigating back to sign-in. Callers invoke it from the navigation
  /// action rather than from `initState`, because Riverpod forbids writing
  /// to a provider while the widget tree is building.
  void clearMessages() => state = const AuthFormState();

  Future<void> signIn({required String email, required String password}) {
    return _submit(
      email: email,
      password: password,
      action: () => _repository.signInWithEmail(email: email, password: password),
    );
  }

  Future<void> createAccount({required String email, required String password}) {
    return _submit(
      email: email,
      password: password,
      requireStrongPassword: true,
      action: () => _repository.registerWithEmail(email: email, password: password),
    );
  }

  Future<void> signInWithGoogle() => _run(_repository.signInWithGoogle);

  Future<void> sendPasswordReset(String email) async {
    if (state.busy) return;
    if (!_looksLikeEmail(email)) {
      state = const AuthFormState(
        failure: AppFailure(FailureKind.unknown, 'Enter a valid email address.'),
      );
      return;
    }

    state = const AuthFormState(busy: true);
    final result = await _repository.sendPasswordResetEmail(email);

    // Success is reported the same way whether or not an account exists —
    // see the screen's copy. Telling the user "no such account" would hand
    // an attacker the account check that Firebase's enumeration protection
    // exists to deny them.
    state = switch (result) {
      Ok() => AuthFormState(resetRequestedFor: email.trim()),
      Err(:final failure) => AuthFormState(failure: failure),
    };
  }

  Future<void> _submit({
    required String email,
    required String password,
    required Future<Result<Object?>> Function() action,
    bool requireStrongPassword = false,
  }) async {
    if (state.busy) return;

    final problem = _validate(
      email: email,
      password: password,
      requireStrongPassword: requireStrongPassword,
    );
    if (problem != null) {
      state = AuthFormState(failure: problem);
      return;
    }

    await _run(action);
  }

  /// Runs a provider flow and reduces the outcome into the form state.
  /// Success needs no handling here: the auth stream emits, and the gate
  /// swaps the screen out from under this controller.
  Future<void> _run(Future<Result<Object?>> Function() action) async {
    if (state.busy) return;
    state = const AuthFormState(busy: true);

    final result = await action();
    state = switch (result) {
      Ok() => const AuthFormState(),
      Err(:final failure) when isCancellation(failure) => const AuthFormState(),
      Err(:final failure) => AuthFormState(failure: failure),
    };
  }

  /// Local checks only, to save a round trip on the obvious mistakes. The
  /// provider remains the authority on whether a credential is good.
  AppFailure? _validate({
    required String email,
    required String password,
    required bool requireStrongPassword,
  }) {
    if (!_looksLikeEmail(email)) {
      return const AppFailure(FailureKind.unknown, 'Enter a valid email address.');
    }
    if (password.isEmpty) {
      return AppFailure(
        FailureKind.unknown,
        requireStrongPassword ? 'Pick a password.' : 'Enter your password.',
      );
    }
    if (requireStrongPassword && password.length < minimumPasswordLength) {
      return const AppFailure(
        FailureKind.unknown,
        'Pick a password of at least $minimumPasswordLength characters.',
      );
    }
    return null;
  }

  static bool _looksLikeEmail(String value) {
    final trimmed = value.trim();
    return trimmed.contains('@') && trimmed.contains('.') && trimmed.length >= 5;
  }
}

/// Firebase's own floor. Checked locally so the strength hint under the
/// password field can be honest before anything is sent.
const int minimumPasswordLength = 6;

final authControllerProvider = NotifierProvider<AuthController, AuthFormState>(AuthController.new);
