import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../domain/models/project.dart';

/// Every stored project, newest first. Throws the [AppFailure] into the
/// async error state so the screen can show what actually went wrong.
final projectSummariesProvider = FutureProvider<List<ProjectSummary>>((ref) async {
  final result = await ref.watch(projectRepositoryProvider).listSummaries();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

/// The project to offer at the top of the library: whatever was open last.
/// When that project is still flagged as left open, the app was killed with
/// it open and the offer becomes a crash recovery rather than a plain resume.
final resumeCandidateProvider = FutureProvider<ProjectSummary?>((ref) async {
  final repository = ref.watch(projectRepositoryProvider);
  final summaries = await ref.watch(projectSummariesProvider.future);
  final lastId = (await repository.readLastOpenedId()).valueOrNull;
  if (lastId == null) return null;
  for (final summary in summaries) {
    if (summary.id == lastId) return summary;
  }
  return null;
});

/// Library-level actions. Each one refreshes the list it just changed, so
/// the screen never has to remember to invalidate anything.
class LibraryController {
  final Ref _ref;
  const LibraryController(this._ref);

  Future<Result<void>> delete(String id) async {
    final repository = _ref.read(projectRepositoryProvider);
    final result = await repository.delete(id);
    if ((await repository.readLastOpenedId()).valueOrNull == id) {
      await repository.writeLastOpenedId(null);
    }
    _refresh();
    return result;
  }

  Future<Result<Project>> duplicate(String id) async {
    final repository = _ref.read(projectRepositoryProvider);
    final loaded = await repository.load(id);
    if (loaded case Err(:final failure)) return Err(failure);

    final source = loaded.valueOrNull!;
    final copy = Project.create(
      title: '${source.title} COPY',
      settings: source.settings,
      blocks: source.blocks,
      ownerId: source.ownerId,
    );
    final saved = await repository.save(copy);
    _refresh();
    return saved;
  }

  Future<Result<Project>> rename(String id, String title) async {
    final trimmed = title.trim();
    final repository = _ref.read(projectRepositoryProvider);
    final loaded = await repository.load(id);
    if (loaded case Err(:final failure)) return Err(failure);
    if (trimmed.isEmpty) return loaded;

    final saved = await repository.save(loaded.valueOrNull!.copyWith(title: trimmed).touch());
    _refresh();
    return saved;
  }

  void _refresh() => _ref.invalidate(projectSummariesProvider);
}

final libraryControllerProvider = Provider<LibraryController>(LibraryController.new);
