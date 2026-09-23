import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../data/sources/session_store.dart';
import '../../../domain/models/entitlement.dart';
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

/// One card on the library: a project and its reel number.
class LibraryItem {
  final ProjectSummary summary;

  /// "01", "02"… — numbered by creation, like reels, so a project keeps its
  /// number however recently it was edited.
  final int reel;

  const LibraryItem(this.summary, this.reel);
}

/// The library as the screen draws it: projects newest-first, numbered by
/// creation, with the plan's slot count.
class LibraryView {
  final List<LibraryItem> items;
  final Entitlement entitlement;

  const LibraryView({required this.items, required this.entitlement});

  int get count => items.length;
  int? get limit => entitlement.projectLimit;
  bool get isFull => !entitlement.canAddProject(count);
  int? get slotsLeft => entitlement.slotsLeft(count);

  /// The reel number the next project will take.
  int get nextReel => count + 1;

  /// "Reel · 2 of 3 · Free", "Reel · 3 of 3 · Full", "Reel · 7 · Pro".
  String get reelLabel => switch (limit) {
        null => 'Reel · $count · Pro',
        final limit when isFull => 'Reel · $count of $limit · Full',
        final limit => 'Reel · $count of $limit · Free',
      };
}

final libraryViewProvider = FutureProvider<LibraryView>((ref) async {
  final summaries = await ref.watch(projectSummariesProvider.future);
  final entitlement = ref.watch(entitlementProvider).value ?? const Entitlement.free();

  final byCreation = [...summaries]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final reels = {for (final (i, s) in byCreation.indexed) s.id: i + 1};
  return LibraryView(
    items: [for (final s in summaries) LibraryItem(s, reels[s.id]!)],
    entitlement: entitlement,
  );
});

/// Transient library UI: the just-duplicated copy shown highlighted (1.7),
/// and "free up a slot" mode, where every card offers delete (1.6).
class LibraryUiState {
  final String? highlightedId;
  final bool freeingSlot;

  const LibraryUiState({this.highlightedId, this.freeingSlot = false});
}

class LibraryUi extends Notifier<LibraryUiState> {
  @override
  LibraryUiState build() => const LibraryUiState();

  void highlight(String? id) => state = LibraryUiState(highlightedId: id, freeingSlot: state.freeingSlot);

  void setFreeingSlot(bool on) => state = LibraryUiState(highlightedId: state.highlightedId, freeingSlot: on);
}

final libraryUiProvider = NotifierProvider<LibraryUi, LibraryUiState>(LibraryUi.new);

/// Library-level actions. Each one refreshes what it changed, so the screen
/// never has to remember to invalidate anything.
class LibraryController {
  final Ref _ref;
  const LibraryController(this._ref);

  /// Deletes a project and returns it, so the ten-second undo can put it
  /// back exactly as it was.
  Future<Result<Project>> delete(String id) async {
    final repository = _ref.read(projectRepositoryProvider);
    final loaded = await repository.load(id);
    if (loaded case Err(:final failure)) return Err(failure);

    final result = await repository.delete(id);
    if (result case Err(:final failure)) return Err(failure);

    final session = _ref.read(sessionStoreProvider);
    final state = await session.read();
    if (state.lastOpenedProjectId == id) await session.setLastOpened(null);
    if (state.leftOpenProjectId == id) await session.setLeftOpen(null);
    _refresh();
    return loaded;
  }

  /// Undo for [delete]: writes the project back unchanged, same id and
  /// timestamps, so it returns to the same place in the list.
  Future<Result<Project>> restore(Project project) async {
    final saved = await _ref.read(projectRepositoryProvider).save(project);
    _refresh();
    return saved;
  }

  /// Copies a project into a new slot. Refused with [slotsFull] when the
  /// plan has no slot left — the cap is enforced here, not by hiding a
  /// button, so no path around the UI can exceed it.
  Future<Result<Project>> duplicate(String id) async {
    if (!await canAddProject()) return const Err(slotsFull);

    final repository = _ref.read(projectRepositoryProvider);
    final loaded = await repository.load(id);
    if (loaded case Err(:final failure)) return Err(failure);

    final source = loaded.valueOrNull!;
    final copy = Project.create(
      title: sanitizeProjectTitle('${source.title} (copy)') ?? 'Untitled project (copy)',
      settings: source.settings,
      blocks: source.blocks,
      ownerId: source.ownerId,
      now: _ref.read(clockProvider)(),
    );
    final saved = await repository.save(copy);
    if (saved is Ok) _ref.read(libraryUiProvider.notifier).highlight(copy.id);
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

  /// Whether one more project fits the plan right now.
  Future<bool> canAddProject() async {
    final summaries = await _ref.read(projectSummariesProvider.future);
    final entitlement = _ref.read(entitlementProvider).value ?? const Entitlement.free();
    return entitlement.canAddProject(summaries.length);
  }

  void _refresh() {
    _ref.invalidate(projectSummariesProvider);
    _ref.invalidate(sessionStateProvider);
  }
}

final libraryControllerProvider = Provider<LibraryController>(LibraryController.new);
