import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// The dark toast with an optional action — "Duplicated · slots now full
/// **Undo**", "Removed "Filming locations" · runtime 2:38 **Undo**".
///
/// Built on [SnackBar] so it inherits queueing, swipe-to-dismiss and screen
/// reader announcement; the theme gives it the ink fill and radius. Undo
/// windows default to the design's ten seconds.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showEcToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 10),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: actionLabel == null ? const Duration(seconds: 4) : duration,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      action: actionLabel == null
          ? null
          : SnackBarAction(label: actionLabel, textColor: context.palette.accentOnBlack, onPressed: onAction ?? () {}),
    ),
  );
}
