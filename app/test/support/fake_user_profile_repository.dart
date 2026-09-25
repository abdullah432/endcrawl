import 'dart:async';

import 'package:lastreel/core/result.dart';
import 'package:lastreel/data/repositories/user_profile_repository.dart';
import 'package:lastreel/domain/models/user_profile.dart';

/// In-memory [UserProfileRepository].
class FakeUserProfileRepository implements UserProfileRepository {
  final _controller = StreamController<UserProfile>.broadcast();
  UserProfile profile;
  int saves = 0;
  bool deleted = false;

  FakeUserProfileRepository([this.profile = const UserProfile()]);

  @override
  Stream<UserProfile> watch() async* {
    yield profile;
    yield* _controller.stream;
  }

  @override
  Future<Result<void>> save(UserProfile next) async {
    saves++;
    profile = next;
    _controller.add(next);
    return const Ok(null);
  }

  @override
  Future<Result<void>> delete() async {
    deleted = true;
    profile = const UserProfile();
    _controller.add(profile);
    return const Ok(null);
  }
}
