import 'dart:async';

import 'package:endcrawl/core/result.dart';
import 'package:endcrawl/data/repositories/auth_repository.dart';
import 'package:endcrawl/domain/models/app_user.dart';

const testUser = AppUser(uid: 'test-uid', email: 'mara@example.com', displayName: 'Mara Oyelaran');

/// In-memory [AuthRepository] for widget tests — the same contract, no
/// platform channels.
class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast();

  AppUser? _user;

  /// Set to make the next call fail, for exercising error states.
  AppFailure? failWith;

  int signInWithEmailCalls = 0;
  int signInWithGoogleCalls = 0;
  int registerCalls = 0;
  String? passwordResetSentTo;

  FakeAuthRepository({AppUser? initialUser}) : _user = initialUser;

  /// Emits the restored session the way Firebase does on startup. Tests that
  /// want the pre-restore state simply don't call it.
  void emitInitial() => _controller.add(_user);

  void dispose() => _controller.close();

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  AppUser? get currentUser => _user;

  void _signIn(AppUser user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Future<Result<AppUser>> signInWithEmail({required String email, required String password}) async {
    signInWithEmailCalls++;
    if (failWith case final failure?) return Err(failure);
    final user = AppUser(uid: 'test-uid', email: email);
    _signIn(user);
    return Ok(user);
  }

  @override
  Future<Result<AppUser>> registerWithEmail({required String email, required String password}) async {
    registerCalls++;
    if (failWith case final failure?) return Err(failure);
    final user = AppUser(uid: 'test-uid', email: email);
    _signIn(user);
    return Ok(user);
  }

  @override
  Future<Result<AppUser>> signInWithGoogle() async {
    signInWithGoogleCalls++;
    if (failWith case final failure?) return Err(failure);
    _signIn(testUser);
    return const Ok(testUser);
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    if (failWith case final failure?) return Err(failure);
    passwordResetSentTo = email.trim();
    return const Ok(null);
  }

  @override
  Future<Result<void>> signOut() async {
    if (failWith case final failure?) return Err(failure);
    _user = null;
    _controller.add(null);
    return const Ok(null);
  }
}
