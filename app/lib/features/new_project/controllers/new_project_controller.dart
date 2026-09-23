import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../domain/models/project.dart';
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
  /// here, before any screen of the flow, so nobody fills in a template
  /// only to be stopped at the end.
  Future<bool> begin(ProjectTemplate? template) async {
    if (!await _ref.read(libraryControllerProvider).canAddProject()) return false;
    final project = _ref.read(projectControllerProvider.notifier);
    if (template == null) {
      project.createEmpty();
    } else {
      project.createFromTemplate(template);
    }
    return true;
  }

  /// The block count a template starts with — for "24 fps · 2.39:1 ·
  /// 18 blocks", derived from the seed so it can never drift.
  int blockCountOf(ProjectTemplate template) => _templates.seed(template.id).length;

  /// "Discard" on the recovery card: stops offering it. The project itself
  /// stays in the library — it was autosaved, and a discard that deleted
  /// work would be the worst possible mis-tap.
  Future<void> dismissRecovery() async {
    await _ref.read(sessionStoreProvider).setLeftOpen(null);
    _ref.invalidate(sessionStateProvider);
  }
}

final newProjectControllerProvider = Provider<NewProjectController>(NewProjectController.new);
