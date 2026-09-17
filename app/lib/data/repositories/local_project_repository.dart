import '../../core/result.dart';
import '../../domain/models/credit_block.dart';
import '../../domain/models/project.dart';
import '../sources/project_local_store.dart';
import 'project_repository.dart';

/// On-device implementation of [ProjectRepository], backed by JSON documents
/// on disk. Translates every storage or decoding error into an [AppFailure]
/// so failures never cross this boundary as raw exceptions.
class LocalProjectRepository implements ProjectRepository {
  final ProjectLocalStore store;

  LocalProjectRepository(this.store);

  @override
  Future<Result<List<ProjectSummary>>> listSummaries() async {
    return _guard(() async {
      final raw = await store.readAll();
      final summaries = <ProjectSummary>[];
      for (final json in raw) {
        try {
          summaries.add(Project.fromJson(json).summary);
        } on Object {
          // A document this build can't read (newer schema, unknown block
          // type) is skipped here so it can't take the whole library down.
          // Opening it directly still surfaces the real error.
          continue;
        }
      }
      summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return summaries;
    });
  }

  @override
  Future<Result<Project>> load(String id) async {
    return _guard(() async {
      final json = await store.read(id);
      if (json == null) throw const _NotFound();
      return Project.fromJson(json);
    });
  }

  @override
  Future<Result<Project>> save(Project project) async {
    return _guard(() async {
      await store.write(project.id, project.toJson());
      return project;
    });
  }

  @override
  Future<Result<void>> delete(String id) => _guard(() => store.delete(id));

  @override
  Future<Result<String?>> readLastOpenedId() => _guard(store.readLastOpenedId);

  @override
  Future<Result<void>> writeLastOpenedId(String? id) => _guard(() => store.writeLastOpenedId(id));

  Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Ok(await body());
    } on _NotFound {
      return const Err(AppFailure.notFound('That project no longer exists.'));
    } on UnsupportedSchemaVersionException catch (e, s) {
      return Err(AppFailure(
        FailureKind.serialization,
        'This project was made with a newer version of EndCrawl.',
        cause: e,
        stackTrace: s,
      ));
    } on UnknownDocumentTypeException catch (e, s) {
      return Err(AppFailure(
        FailureKind.serialization,
        'This project contains a block this version does not understand.',
        cause: e,
        stackTrace: s,
      ));
    } on FormatException catch (e, s) {
      return Err(AppFailure(
        FailureKind.serialization,
        'This project file is damaged and could not be read.',
        cause: e,
        stackTrace: s,
      ));
    } on Object catch (e, s) {
      return Err(AppFailure(
        FailureKind.storage,
        'Could not reach on-device storage.',
        cause: e,
        stackTrace: s,
      ));
    }
  }
}

class _NotFound implements Exception {
  const _NotFound();
}
