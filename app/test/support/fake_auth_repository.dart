import 'dart:async';

import 'package:endcrawl/core/result.dart';
import 'package:endcrawl/data/repositories/auth_repository.dart';
import 'package:endcrawl/domain/models/app_user.dart';

const testUser = AppUser(
  uid: 'test-uid',
  email: 'mara@example.com',
  displayName: 'Mara Oyelaran',
  isEmailVerified: true,
  methods: {SignInMethod.google},
);

/// In-memory [AuthRepository] for widget tests — the same contract, no
/// platform channels.
class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();

  AppUser? _user;

  /// Set to make the next call fail, for exercising error states.
  AppFailure? failWith;

  int signInWithEmailCalls = 0;
  int signInWithGoogleCalls = 0;
  int signInWithAppleCalls = 0;
  int registerCalls = 0;
  int verificationEmailsSent = 0;
  int reloadCalls = 0;
  bool deleted = false;
  String? passwordResetSentTo;
  String? registeredName;

  /// What [reloadUser] should find — flip to simulate the link being
  /// clicked in Mail.
  bool verifyOnReload = false;

  FakeAuthRepository({AppUser? initialUser}) : _user = initialUser;

  void dispose() => _controller.close();

  @override
  Stream<AppUser?> userChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _user;

  void _emit(AppUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Future<Result<AppUser>> signInWithEmail({required String email, required String password}) async {
    signInWithEmailCalls++;
    if (failWith case final failure?) return Err(failure);
    final user = AppUser(uid: 'test-uid', email: email, isEmailVerified: true, methods: const {SignInMethod.password});
    _emit(user);
    return Ok(user);
  }

  @override
  Future<Result<AppUser>> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    registerCalls++;
    registeredName = name;
    if (failWith case final failure?) return Err(failure);
    verificationEmailsSent++;
    final user = AppUser(uid: 'test-uid', email: email, displayName: name, methods: const {SignInMethod.password});
    _emit(user);
    return Ok(user);
  }

  @override
  Future<Result<AppUser>> signInWithGoogle() async {
    signInWithGoogleCalls++;
    if (failWith case final failure?) return Err(failure);
    _emit(testUser);
    return const Ok(testUser);
  }

  @override
  Future<Result<AppUser>> signInWithApple() async {
    signInWithAppleCalls++;
    if (failWith case final failure?) return Err(failure);
    const user = AppUser(uid: 'test-uid', email: 'm@privaterelay.appleid.com', isEmailVerified: true, methods: {SignInMethod.apple});
    _emit(user);
    return const Ok(user);
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    if (failWith case final failure?) return Err(failure);
    passwordResetSentTo = email.trim();
    return const Ok(null);
  }

  @override
  Future<Result<void>> sendEmailVerification() async {
    if (failWith case final failure?) return Err(failure);
    verificationEmailsSent++;
    return const Ok(null);
  }

  @override
  Future<Result<AppUser>> reloadUser() async {
    reloadCalls++;
    final user = _user;
    if (user == null) return const Err(AppFailure(FailureKind.permission, 'Signed out.'));
    if (verifyOnReload && !user.isEmailVerified) {
      final verified = AppUser(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        isEmailVerified: true,
        methods: user.methods,
      );
      _emit(verified);
      return Ok(verified);
    }
    return Ok(user);
  }

  @override
  Future<Result<void>> updateDisplayName(String name) async {
    final user = _user;
    if (user == null) return const Err(AppFailure(FailureKind.permission, 'Signed out.'));
    _emit(AppUser(uid: user.uid, email: user.email, displayName: name, isEmailVerified: user.isEmailVerified, methods: user.methods));
    return const Ok(null);
  }

  int reauthentications = 0;
  String? reauthPassword;

  Future<Result<AppUser>> _withMethods(Set<SignInMethod> Function(Set<SignInMethod>) change) async {
    if (failWith case final failure?) return Err(failure);
    final user = _user;
    if (user == null) return const Err(AppFailure(FailureKind.permission, 'Signed out.'));
    final next = user.copyWith(methods: change({...user.methods}));
    _emit(next);
    return Ok(next);
  }

  @override
  Future<Result<AppUser>> linkGoogle() => _withMethods((m) => m..add(SignInMethod.google));

  @override
  Future<Result<AppUser>> linkApple() => _withMethods((m) => m..add(SignInMethod.apple));

  @override
  Future<Result<AppUser>> linkPassword({required String email, required String password}) =>
      _withMethods((m) => m..add(SignInMethod.password));

  @override
  Future<Result<AppUser>> unlink(SignInMethod method) async {
    if (!(_user?.canUnlink(method) ?? false)) return const Err(lastSignInMethod);
    return _withMethods((m) => m..remove(method));
  }

  @override
  Future<Result<void>> reauthenticate({String? password}) async {
    reauthentications++;
    reauthPassword = password;
    if (failWith case final failure?) return Err(failure);
    return const Ok(null);
  }

  @override
  Future<Result<void>> deleteCurrentUser() async {
    if (failWith case final failure?) return Err(failure);
    deleted = true;
    _emit(null);
    return const Ok(null);
  }

  @override
  Future<Result<void>> signOut() async {
    if (failWith case final failure?) return Err(failure);
    _emit(null);
    return const Ok(null);
  }
}
