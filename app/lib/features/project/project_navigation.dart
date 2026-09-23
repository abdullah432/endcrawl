import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/result.dart';
import '../../core/widgets/ec_toast.dart';
import '../editor/screens/editor_screen.dart';
import '../library/controllers/library_controller.dart';
import '../monitor/controllers/playback_controller.dart';
import 'controllers/project_controller.dart';

// Navigation helpers take a BuildContext and read the provider container
// from it, rather than a WidgetRef: they're often called from a sheet that
// has just popped, whose ref is disposed before the awaited work finishes.

/// Opens a stored project in the editor — from a library card, the action
/// sheet, or the crash-recovery card. One path, so every entry point marks
/// the project open (what makes a kill recoverable) the same way.
Future<void> openStoredProject(BuildContext context, String id) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final result = await container.read(projectControllerProvider.notifier).openProject(id);
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      await enterEditor(context);
    case Err(:final failure):
      showEcToast(context, failure.message);
  }
}

/// Shows the editor for whatever [ProjectController] holds — a stored
/// project just loaded, or a new one just created — and refreshes the
/// library when the editor closes. [replaceFlow] drops the new-project
/// screens underneath, so Back from the editor returns to the library.
Future<void> enterEditor(BuildContext context, {bool replaceFlow = false}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  container.read(playbackControllerProvider.notifier).resetToHead();
  // Flags the document as open before the editor appears, so a kill while
  // editing leaves something to recover. For a new project this is also its
  // first save, which is what makes it appear in the library.
  await container.read(projectControllerProvider.notifier).markOpened();
  if (!context.mounted) return;
  final route = MaterialPageRoute<void>(builder: (_) => const EditorScreen());
  final navigator = Navigator.of(context);
  if (replaceFlow) {
    await navigator.pushAndRemoveUntil(route, (r) => r.isFirst);
  } else {
    await navigator.push(route);
  }
  container.invalidate(projectSummariesProvider);
}
