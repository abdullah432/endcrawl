import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../data/sources/session_store.dart';
import '../../../domain/models/project.dart';

/// Every stored project, newest first. Throws the [AppFailure] into the
/// async error state so the screen can show what actually went wrong.
///
/// Reads are served from Firestore's local cache when the device is offline,
/// so this does not need an offline branch of its own.
final projectSummariesProvider = FutureProvider<List<ProjectSummary>>((ref) async {
  final result = await ref.watch(projectRepositoryProvider).listSummaries();
  return switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw failure,
  };
});

/// This device's session: which project it had open, and whether it was
/// still open when the app died.
final sessionStateProvider = FutureProvider<SessionState>((ref) {
  return ref.watch(sessionStoreProvider).read();
});

/// The project to offer at the top of the library, and whether the offer is
/// a crash recovery rather than a plain resume.
class ResumeCandidate {
  final ProjectSummary summary;
  final bool recovered;

  const ResumeCandidate({required this.summary, required this.recovered});
}

final resumeCandidateProvider = FutureProvider<ResumeCandidate?>((ref) async {
  final session = await ref.watch(sessionStateProvider.future);
  final lastId = session.lastOpenedProjectId;
  if (lastId == null) return null;

  final summaries = await ref.watch(projectSummariesProvider.future);
  for (final summary in summaries) {
    if (summary.id == lastId) {
      return ResumeCandidate(summary: summary, recovered: session.wasLeftOpen(lastId));
    }
  }
  // The project was deleted, or belongs to a different account than the one
  // now signed in.
  return null;
});

/// Library-level actions. Each one refreshes the list it just changed, so
/// the screen never has to remember to invalidate anything.
class LibraryController {
  final Ref _ref;
  const LibraryController(this._ref);

  Future<Result<void>> delete(String id) async {
    final result = await _ref.read(projectRepositoryProvider).delete(id);
    final session = _ref.read(sessionStoreProvider);
    final state = await session.read();
    if (state.lastOpenedProjectId == id) await session.setLastOpened(null);
    if (state.leftOpenProjectId == id) await session.setLeftOpen(null);
    _refresh();
    return result;
  }

  Future<Result<Project>> duplicate(String id) async {
    final repository = _ref.read(projectRepositoryProvider);
    final loaded = await repository.load(id);
    if (loaded case Err(:final failure)) return Err(failure);

    final source = loaded.valueOrNull!;
    final copy = Project.create(
      title: sanitizeProjectTitle('${source.title} COPY') ?? 'UNTITLED COPY',
      settings: source.settings,
      blocks: source.blocks,
      ownerId: source.ownerId,
    );
    final saved = await repository.save(copy);
    _refresh();
    return saved;
  }

  Future<Result<Project>> rename(String id, String title) async {
    final clean = sanitizeProjectTitle(title);
    final repository = _ref.read(projectRepositoryProvider);
    final loaded = await repository.load(id);
    if (loaded case Err(:final failure)) return Err(failure);
    if (clean == null) return loaded;

    final saved = await repository.save(loaded.valueOrNull!.copyWith(title: clean).touch());
    _refresh();
    return saved;
  }

  void _refresh() {
    _ref.invalidate(projectSummariesProvider);
    _ref.invalidate(sessionStateProvider);
  }
}

final libraryControllerProvider = Provider<LibraryController>(LibraryController.new);
