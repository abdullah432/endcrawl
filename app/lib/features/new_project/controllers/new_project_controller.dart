import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../domain/models/project.dart';
import '../../../domain/models/user_profile.dart';
import '../../library/controllers/library_controller.dart';
import '../../project/controllers/project_controller.dart';

/// The project this device was editing when the app died, if it still
/// exists — offered first on the new-project sheet (2.1), above the
/// templates, because it's the most urgent choice.
final recoveryCandidateProvider = FutureProvider<ProjectSummary?>((ref) async {
  final session = await ref.watch(sessionStateProvider.future);
  final id = session.leftOpenProjectId;
  if (id == null) return null;
  final summaries = await ref.watch(projectSummariesProvider.future);
  for (final s in summaries) {
    if (s.id == id) return s;
  }
  return null;
});

/// Starting a project: the plan check, then a fresh document in
/// [ProjectController]. Nothing is saved until the editor opens it, so
/// backing out of 2.2 or 2.3 leaves nothing behind.
class NewProjectController {
  final Ref _ref;
  const NewProjectController(this._ref);

  static const _templates = TemplateRepository();

  /// False when the plan has no free slot — the caller shows 1.6. Checked
  /// first, before any screen of the flow, so nobody works through a
  /// template only to be stopped at the end.
  Future<bool> canStart() => _ref.read(libraryControllerProvider).canAddProject();

  /// A document from [template] with the sections ticked on 2.2.
  void createFromTemplate(ProjectTemplate template, Set<String> include) =>
      _ref.read(projectControllerProvider.notifier).createFromTemplate(template, include: include);

  /// "Start empty": a blank document on the account's default canvas and
  /// frame rate.
  ///
  /// Waits briefly for the profile (it may not have been read yet this
  /// session); a slow or failed read falls back to the built-in defaults
  /// rather than holding the person up.
  Future<void> createEmpty() async {
    // Listened rather than read: an unlistened stream provider is paused
    // and would never deliver.
    final sub = _ref.listen(userProfileProvider.future, (_, _) {});
    final UserProfile profile;
    try {
      profile = await sub.read().timeout(const Duration(seconds: 2)).catchError((Object _) => const UserProfile());
    } finally {
      sub.close();
    }
    final prefs = profile.preferences;
    _ref.read(projectControllerProvider.notifier).createEmpty(
          fps: prefs.defaultFps,
          formatId: prefs.defaultFormatId,
          safeGuides: prefs.safeGuides,
        );
  }

  List<TemplateSection> sectionsOf(ProjectTemplate template) => _templates.sections(template.id);

  /// The blocks a template starts with — for "24 fps · 2.39:1 · 28 blocks",
  /// derived from the sections so it can never drift.
  int blockCountOf(ProjectTemplate template) => _templates.seed(template.id).length;

  /// How many blocks the chosen sections add — "Continue with 26 blocks".
  int blockCountFor(ProjectTemplate template, Set<String> include) =>
      _templates.blocksFor(template.id, include: include).length;

  /// "Discard" on the recovery card: stops offering it. The project itself
  /// stays in the library — it was autosaved, and a discard that deleted
  /// work would be the worst possible mis-tap.
  Future<void> dismissRecovery() async {
    await _ref.read(sessionStoreProvider).setLeftOpen(null);
    _ref.invalidate(sessionStateProvider);
  }
}

final newProjectControllerProvider = Provider<NewProjectController>(NewProjectController.new);
