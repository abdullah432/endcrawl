import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatting.dart';
import '../../core/widgets/ec_toast.dart';
import '../../domain/models/block_catalog.dart';
import '../project/controllers/project_controller.dart';

/// Removes a block and offers it back (3.5): "Removed “Filming locations”
/// · runtime 2:38 — Undo". Shared by the swipe action and the edit sheet.
///
/// The runtime is read after the monitor has re-measured the shorter roll,
/// so at a locked speed it is the new runtime, not the old one.
Future<void> removeBlockWithUndo(BuildContext context, String id) async {
  final container = ProviderScope.containerOf(context, listen: false);
  // The row that asked is about to disappear; the overlay outlives it.
  final overlay = Overlay.of(context);
  final controller = container.read(projectControllerProvider.notifier);
  final index = container.read(projectControllerProvider).blocks.indexWhere((b) => b.id == id);
  final removed = controller.deleteBlock(id);
  if (removed == null) return;

  await SchedulerBinding.instance.endOfFrame;
  await SchedulerBinding.instance.endOfFrame;
  if (!overlay.mounted) return;
  final runtime = container.read(projectControllerProvider).runtime;
  showEcToastOn(
    overlay,
    'Removed “${describeBlock(removed).title}” · runtime ${formatClock(runtime.inMilliseconds / 1000)}',
    actionLabel: 'Undo',
    onAction: () => controller.restoreBlock(removed, index),
  );
}
