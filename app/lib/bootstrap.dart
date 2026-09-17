import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'data/repositories/local_project_repository.dart';
import 'data/repositories/project_repository.dart';
import 'data/sources/project_local_store.dart';

/// The app's single dependency-injection seam.
///
/// Nothing above the data layer names a concrete store: screens and
/// controllers read [projectRepositoryProvider], and the implementation is
/// chosen exactly once, here. Swapping in (or composing) a Firestore-backed
/// repository later is a change to [createProviderOverrides] and nothing
/// else; tests override the same provider with an in-memory fake.
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  throw StateError(
    'projectRepositoryProvider was not overridden — the ProviderScope must be '
    'created with createProviderOverrides(), or with a test override.',
  );
});

/// Resolves platform paths and builds the repository the root
/// [ProviderScope] is seeded with. Called before `runApp`, so the first frame
/// already has a working repository rather than an async loading state on
/// every screen.
Future<ProjectRepository> createProjectRepository() async {
  final documents = await getApplicationDocumentsDirectory();
  final store = ProjectLocalStore(Directory(p.join(documents.path, 'projects')));
  await store.ensureReady();
  return LocalProjectRepository(store);
}
