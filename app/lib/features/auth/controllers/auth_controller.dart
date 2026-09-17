import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../data/repositories/auth_repository.dart';

enum AuthMode { signIn, register }

class AuthFormState {
  final AuthMode mode;
  final bool busy;

  /// Set when a submission failed. Cancellations never land here — backing
  /// out of the Google sheet is not an error worth showing.
  final AppFailure? failure;

  /// Set after a password-reset email goes out.
  final String? notice;

  const AuthFormState({
    this.mode = AuthMode.signIn,
    this.busy = false,
    this.failure,
    this.notice,
  });

  AuthFormState copyWith({
    AuthMode? mode,
    bool? busy,
    AppFailure? failure,
    String? notice,
    bool clearMessages = false,
  }) {
    return AuthFormState(
      mode: mode ?? this.mode,
      busy: busy ?? this.busy,
      failure: clearMessages ? null : (failure ?? this.failure),
      notice: clearMessages ? null : (notice ?? this.notice),
    );
  }
}

/// Drives the sign-in screen. Deliberately owns no notion of *who* is signed
/// in — that is `authStateProvider`, fed by the provider's own stream, so
/// there is one source of truth for session state and this only handles the
/// form around it.
class AuthController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  void setMode(AuthMode mode) => state = state.copyWith(mode: mode, clearMessages: true);

  void clearMessages() => state = state.copyWith(clearMessages: true);

  Future<void> submitEmail({required String email, required String password}) async {
    if (state.busy) return;

    final problem = _validate(email: email, password: password);
    if (problem != null) {
      state = state.copyWith(failure: problem, clearMessages: false);
      return;
    }

    await _run(() => state.mode == AuthMode.signIn
        ? _repository.signInWithEmail(email: email, password: password)
        : _repository.registerWithEmail(email: email, password: password));
  }

  Future<void> signInWithGoogle() => _run(_repository.signInWithGoogle);

  Future<void> sendPasswordReset(String email) async {
    if (state.busy) return;
    if (!_looksLikeEmail(email)) {
      state = state.copyWith(
        failure: const AppFailure(FailureKind.unknown, 'Enter your email address first.'),
      );
      return;
    }

    state = state.copyWith(busy: true, clearMessages: true);
    final result = await _repository.sendPasswordResetEmail(email);
    state = switch (result) {
      Ok() => state.copyWith(busy: false, notice: 'Password reset sent to ${email.trim()}.'),
      Err(:final failure) => state.copyWith(busy: false, failure: failure),
    };
  }

  /// Runs a provider flow and reduces the outcome into the form state.
  /// Success needs no handling here: the auth stream emits, and the gate
  /// swaps the screen out from under this controller.
  Future<void> _run(Future<Result<Object?>> Function() action) async {
    if (state.busy) return;
    state = state.copyWith(busy: true, clearMessages: true);

    final result = await action();
    state = switch (result) {
      Ok() => state.copyWith(busy: false),
      Err(:final failure) when isCancellation(failure) => state.copyWith(busy: false),
      Err(:final failure) => state.copyWith(busy: false, failure: failure),
    };
  }

  /// Local checks only, to save a round trip on the obvious mistakes. The
  /// provider remains the authority on whether a credential is good.
  AppFailure? _validate({required String email, required String password}) {
    if (!_looksLikeEmail(email)) {
      return const AppFailure(FailureKind.unknown, 'Enter a valid email address.');
    }
    if (password.isEmpty) {
      return const AppFailure(FailureKind.unknown, 'Enter your password.');
    }
    if (state.mode == AuthMode.register && password.length < 6) {
      return const AppFailure(FailureKind.unknown, 'Pick a password of at least 6 characters.');
    }
    return null;
  }

  static bool _looksLikeEmail(String value) {
    final trimmed = value.trim();
    return trimmed.contains('@') && trimmed.contains('.') && trimmed.length >= 5;
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthFormState>(AuthController.new);
