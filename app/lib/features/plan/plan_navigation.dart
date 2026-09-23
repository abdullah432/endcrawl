import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/controllers/library_controller.dart';
import 'screens/pro_sheet.dart';
import 'widgets/slots_full_sheet.dart';

/// What happens when an action needs a slot and none is free: the 1.6
/// sheet, then Pro (6.5) or "free up a slot" mode on the library.
Future<void> handleSlotsFull(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final choice = await SlotsFullSheet.show(context);
  if (!context.mounted) return;
  switch (choice) {
    case SlotsFullChoice.upgrade:
      await ProSheet.show(context);
    case SlotsFullChoice.freeUp:
      container.read(libraryUiProvider.notifier).setFreeingSlot(true);
      Navigator.of(context).popUntil((route) => route.isFirst);
    case null:
      break;
  }
}
