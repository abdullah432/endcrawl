import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/template_repository.dart';
import '../plan/plan_navigation.dart';
import 'controllers/new_project_controller.dart';
import 'screens/canvas_screen.dart';
import 'screens/template_contents_screen.dart';

/// Starts the new-project flow from a picked template (or empty).
///
/// The plan is checked first: with every slot used this opens the "slots
/// full" sheet (1.6) instead, before the person has put any work in. A
/// template goes through its contents (2.2) then the canvas (2.3); "Start
/// empty" goes straight to the canvas.
Future<void> startNewProject(BuildContext context, ProjectTemplate? template) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final newProject = container.read(newProjectControllerProvider);
  if (!await newProject.canStart()) {
    if (context.mounted) await handleSlotsFull(context);
    return;
  }
  if (!context.mounted) return;

  final Widget first;
  if (template == null) {
    await newProject.createEmpty();
    if (!context.mounted) return;
    first = const CanvasScreen();
  } else {
    first = TemplateContentsScreen(template: template);
  }
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => first));
}
