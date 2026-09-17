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

  Future<Result<Project>> load(String id);

  /// Returns the persisted project, which may differ from what was passed
  /// in — a server-backed implementation stamps its own write time.
  Future<Result<Project>> save(Project project);

  Future<Result<void>> delete(String id);
}
