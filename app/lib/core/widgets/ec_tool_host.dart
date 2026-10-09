import 'package:flutter/material.dart';

/// Routes the same tool body into the editor panel instead of a modal route.
class EcToolHost extends InheritedWidget {
  final Future<Object?> Function(WidgetBuilder builder) present;
  final GlobalKey ownerKey;
  final bool enabled;
  const EcToolHost({
    super.key,
    required this.present,
    required this.ownerKey,
    required this.enabled,
    required super.child,
  });
  static BuildContext ownerOf(BuildContext context) =>
      maybeOf(context)?.ownerKey.currentContext ?? context;

  static EcToolHost? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EcToolHost>();

  @override
  bool updateShouldNotify(EcToolHost oldWidget) => enabled != oldWidget.enabled;
}

/// Only the mounted tool subtree sees this completion callback.
class EcPanelPresentation extends InheritedWidget {
  final void Function(Object? result) complete;
  const EcPanelPresentation({
    super.key,
    required this.complete,
    required super.child,
  });
  static EcPanelPresentation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EcPanelPresentation>();

  @override
  bool updateShouldNotify(EcPanelPresentation oldWidget) =>
      complete != oldWidget.complete;
}

void closeEcSheet<T>(BuildContext context, [T? result]) {
  final panel = EcPanelPresentation.maybeOf(context);
  if (panel != null) {
    panel.complete(result);
  } else {
    Navigator.of(context).pop(result);
  }
}
