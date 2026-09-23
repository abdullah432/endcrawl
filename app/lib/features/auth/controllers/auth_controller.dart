import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/password_policy.dart';
import '../../../domain/models/user_profile.dart';

/// Which action is running, so only its button shows a spinner and the
/// others simply disable — "Continue with Apple" shouldn't spin because
/// Google is working.
enum AuthAction { email, apple, google, reset, resendVerification, checkVerification, changeEmail }

/// How long before a reset link or verification email can be re-sent.
/// Shown as "Resend in 0:42" so nobody taps twice and gets two emails.
const resendCooldown = Duration(seconds: 60);

/// Shared form state for the onboarding and auth screens.
class AuthFormState {
  final AuthAction? running;

  /// The last failure. Its [AppFailure.field] says which input it belongs
  /// under; without one, screens show it above the main button.
  /// Cancellations never land here — backing out of a provider sheet is not
  /// an error worth showing anyone.
  final AppFailure? failure;

  /// Set when a reset link was requested — flips 0.4 to its sent state.
  final String? resetSentTo;
  final DateTime? resetSentAt;

  final DateTime? verificationSentAt;

  const AuthFormState({
    this.running,
    this.failure,
    this.resetSentTo,
    this.resetSentAt,
    this.verificationSentAt,
  });

  bool get busy => running != null;

  bool isRunning(AuthAction action) => running == action;

  /// The failure for one input, or null.
  String? errorFor(String field) => failure?.field == field ? failure!.message : null;

  /// A failure that isn't about any one input.
  String? get formError => failure != null && failure!.field == null ? failure!.message : null;

  AuthFormState _copy({
    AuthAction? running,
    bool clearRunning = false,
    AppFailure? failure,
    bool clearFailure = false,
    String? resetSentTo,
    DateTime? resetSentAt,
    DateTime? verificationSentAt,
  }) {
    return AuthFormState(
      running: clearRunning ? null : (running ?? this.running),
      failure: clearFailure ? null : (failure ?? this.failure),
      resetSentTo: resetSentTo ?? this.resetSentTo,
      resetSentAt: resetSentAt ?? this.resetSentAt,
      verificationSentAt: verificationSentAt ?? this.verificationSentAt,
    );
  }
}

/// Drives the onboarding and auth screens.
///
/// Owns no notion of *who* is signed in — that is `authStateProvider`, fed by
/// the provider's own stream. Success is never handled here: the stream
/// emits and the gate swaps the screen out from under this controller.
class AuthController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  DateTime Function() get _now => ref.read(clockProvider);

  /// Resets what the previous screen may have left behind. Called from the
  /// navigation action (Riverpod forbids writing to a provider during build).
  /// Keeps the send timestamps so cooldowns survive moving between screens.
  void clearMessages() => state = AuthFormState(
        resetSentAt: state.resetSentAt,
        verificationSentAt: state.verificationSentAt,
      );

  Future<void> signIn({required String email, required String password}) async {
    final problem = _check([
      if (!looksLikeEmail(email)) _invalid(AuthField.email, 'Enter a valid email address.'),
      if (password.isEmpty) _invalid(AuthField.password, 'Enter your password.'),
    ]);
    if (problem) return;
    await _run(AuthAction.email, () => _auth.signInWithEmail(email: email, password: password));
  }

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
    required bool marketingOptIn,
  }) async {
    final problem = _check([
      if (name.trim().isEmpty) _invalid(AuthField.name, 'Enter your name.'),
      if (!looksLikeEmail(email)) _invalid(AuthField.email, 'Enter a valid email address.'),
      if (!PasswordPolicy.isAcceptable(password))
        _invalid(AuthField.password, 'Use at least ${PasswordPolicy.minLength} characters, including a number.'),
    ]);
    if (problem) return;

    await _run(AuthAction.email, () async {
      final result = await _auth.registerWithEmail(name: name, email: email, password: password);
      if (result case Ok(:final value)) {
        state = state._copy(verificationSentAt: _now());
        // Only an opt-in needs writing: a missing profile document already
        // reads as the default, which is "off".
        if (marketingOptIn) {
          await ref.read(userProfileRepositoryForProvider(value.uid)).save(const UserProfile(marketingOptIn: true));
        }
      }
      return result;
    });
  }

  Future<void> signInWithGoogle() => _run(AuthAction.google, _auth.signInWithGoogle);

  Future<void> signInWithApple() => _run(AuthAction.apple, _auth.signInWithApple);

  /// Seconds left before the reset link can be re-sent, or zero.
  Duration resetCooldownLeft() => _left(state.resetSentAt);

  Duration verificationCooldownLeft() => _left(state.verificationSentAt);

  Future<void> sendPasswordReset(String email) async {
    if (state.busy || resetCooldownLeft() > Duration.zero) return;
    if (_check([if (!looksLikeEmail(email)) _invalid(AuthField.email, 'Enter a valid email address.')])) return;

    state = state._copy(running: AuthAction.reset, clearFailure: true);
    final result = await _auth.sendPasswordResetEmail(email);
    // Success reads the same whether or not an account exists: saying "no
    // such account" would hand out the check Firebase's enumeration
    // protection exists to deny.
    state = switch (result) {
      Ok() => state._copy(clearRunning: true, resetSentTo: email.trim(), resetSentAt: _now()),
      Err(:final failure) => state._copy(clearRunning: true, failure: failure),
    };
  }

  Future<void> resendVerification() async {
    if (state.busy || verificationCooldownLeft() > Duration.zero) return;
    state = state._copy(running: AuthAction.resendVerification, clearFailure: true);
    final result = await _auth.sendEmailVerification();
    state = switch (result) {
      Ok() => state._copy(clearRunning: true, verificationSentAt: _now()),
      Err(:final failure) => state._copy(clearRunning: true, failure: failure),
    };
  }

  /// Re-reads the account; if the link was clicked, the user stream emits a
  /// verified user and the gate moves on by itself.
  Future<void> checkVerification() => _run(AuthAction.checkVerification, _auth.reloadUser, quiet: true);

  /// "Use a different email" on 0.5: the unverified account holds nothing
  /// yet, so it's deleted rather than left behind to squat on the address.
  /// If the provider refuses (session too old), signing out still gets the
  /// person back to the start.
  Future<void> useDifferentEmail() async {
    await _run(AuthAction.changeEmail, () async {
      final deleted = await _auth.deleteCurrentUser();
      if (deleted is Err) return _auth.signOut();
      return deleted;
    }, quiet: true);
  }

  Future<void> _run(AuthAction action, Future<Result<Object?>> Function() body, {bool quiet = false}) async {
    if (state.busy) return;
    state = state._copy(running: action, clearFailure: true);
    final result = await body();
    state = switch (result) {
      Ok() => state._copy(clearRunning: true),
      Err(:final failure) when isCancellation(failure) || quiet => state._copy(clearRunning: true),
      Err(:final failure) => state._copy(clearRunning: true, failure: failure),
    };
  }

  /// Applies the first local validation problem, if any. Local checks only
  /// save a round trip on obvious mistakes; the provider stays the authority.
  bool _check(List<AppFailure> problems) {
    if (state.busy) return true;
    if (problems.isEmpty) return false;
    state = state._copy(failure: problems.first);
    return true;
  }

  static AppFailure _invalid(String field, String message) =>
      AppFailure(FailureKind.unknown, message, field: field);

  Duration _left(DateTime? sentAt) {
    if (sentAt == null) return Duration.zero;
    final left = resendCooldown - _now().difference(sentAt);
    return left.isNegative ? Duration.zero : left;
  }
}

bool looksLikeEmail(String value) {
  final trimmed = value.trim();
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
}

final authControllerProvider = NotifierProvider<AuthController, AuthFormState>(AuthController.new);
