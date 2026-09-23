import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/template_repository.dart';
import '../format/screens/format_screen.dart';
import '../plan/plan_navigation.dart';
import 'controllers/new_project_controller.dart';

/// Starts the new-project flow from a picked template (or empty).
///
/// The plan is checked first: with every slot used this opens the "slots
/// full" sheet (1.6) instead, before the person has put any work in.
Future<void> startNewProject(BuildContext context, ProjectTemplate? template) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final started = await container.read(newProjectControllerProvider).begin(template);
  if (!context.mounted) return;
  if (!started) {
    await handleSlotsFull(context);
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FormatScreen()));
}
