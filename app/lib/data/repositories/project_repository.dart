import '../../core/result.dart';
import '../../domain/models/project.dart';

/// The one seam between the app and wherever projects are stored.
///
/// Everything above this interface — controllers, screens — is storage
/// agnostic. `LocalProjectRepository` is the on-device implementation;
/// a `FirestoreProjectRepository` implementing this same interface is what
/// Firebase support will add, with the choice (or a syncing composite of the
/// two) made once, at injection time in `bootstrap.dart`.
abstract interface class ProjectRepository {
  /// Newest first. Returns the list projection, not whole documents.
  Future<Result<List<ProjectSummary>>> listSummaries();

  /// [listSummaries], kept current: emits again whenever a project is
  /// created, changed or deleted — on this device at once, from others as
  /// they sync. Failures arrive as [AppFailure] stream errors.
  Stream<List<ProjectSummary>> watchSummaries();

  Future<Result<Project>> load(String id);

  /// Returns the persisted project, which may differ from what was passed
  /// in — a server-backed implementation stamps its own write time.
  Future<Result<Project>> save(Project project);

  Future<Result<void>> delete(String id);

  /// Deletes every project of this account — account deletion (7.6).
  Future<Result<void>> deleteAll();
}

/// [ProjectRepository.watchSummaries] for stores without change
/// notifications of their own: lists once, then again after each
/// [changes] event.
Stream<List<ProjectSummary>> relistOnChange(
  Future<Result<List<ProjectSummary>>> Function() list,
  Stream<void> changes,
) async* {
  Future<List<ProjectSummary>> read() async => switch (await list()) {
        Ok(:final value) => value,
        Err(:final failure) => throw failure,
      };
  yield await read();
  await for (final _ in changes) {
    yield await read();
  }
}
