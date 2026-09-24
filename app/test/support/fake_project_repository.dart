import 'dart:async';

import 'package:endcrawl/core/result.dart';
import 'package:endcrawl/data/repositories/project_repository.dart';
import 'package:endcrawl/domain/models/project.dart';

/// In-memory [ProjectRepository] for widget tests — same contract, no disk.
///
/// That this is a drop-in replacement is the point of the interface: it is
/// the same seam a Firestore implementation will occupy.
class FakeProjectRepository implements ProjectRepository {
  final Map<String, Project> projects = {};

  /// Set to make the next call fail, for exercising error states.
  AppFailure? failWith;

  int saveCount = 0;

  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<ProjectSummary>> watchSummaries() => relistOnChange(listSummaries, _changes.stream);

  FakeProjectRepository({List<Project> seed = const []}) {
    for (final project in seed) {
      projects[project.id] = project;
    }
  }

  @override
  Future<Result<List<ProjectSummary>>> listSummaries() async {
    if (failWith case final failure?) return Err(failure);
    final summaries = projects.values.map((p) => p.summary).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Ok(summaries);
  }

  @override
  Future<Result<Project>> load(String id) async {
    if (failWith case final failure?) return Err(failure);
    final project = projects[id];
    if (project == null) return const Err(AppFailure.notFound('No such project.'));
    return Ok(project);
  }

  @override
  Future<Result<Project>> save(Project project) async {
    if (failWith case final failure?) return Err(failure);
    saveCount++;
    projects[project.id] = project;
    _changes.add(null);
    return Ok(project);
  }

  @override
  Future<Result<void>> delete(String id) async {
    if (failWith case final failure?) return Err(failure);
    projects.remove(id);
    _changes.add(null);
    return const Ok(null);
  }

  @override
  Future<Result<void>> deleteAll() async {
    if (failWith case final failure?) return Err(failure);
    projects.clear();
    _changes.add(null);
    return const Ok(null);
  }

}
