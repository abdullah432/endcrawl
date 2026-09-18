import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../controllers/auth_controller.dart';

/// Pushes one auth screen onto another, clearing whatever the previous
/// screen was saying first.
///
/// All four screens share `authControllerProvider`, so without this a
/// failure raised while creating an account would still be on display after
/// navigating back to sign-in. It happens here, at the navigation action,
/// rather than in the destination's `initState` because Riverpod forbids
/// writing to a provider while the widget tree is building.
Future<void> pushAuthScreen(BuildContext context, WidgetRef ref, Widget screen) {
  ref.read(authControllerProvider.notifier).clearMessages();
  return Navigator.of(context).push<void>(_authRoute(screen));
}

/// Pops back, clearing messages for the same reason.
void popAuthScreen(BuildContext context, WidgetRef ref) {
  ref.read(authControllerProvider.notifier).clearMessages();
  Navigator.of(context).pop();
}

/// A fade-through rather than the platform push.
///
/// These screens are one surface changing its question, not a hierarchy
/// being descended, and a horizontal slide would imply a depth that isn't
/// there.
Route<void> _authRoute(Widget screen) {
  return PageRouteBuilder<void>(
    transitionDuration: EcMotion.slow,
    reverseTransitionDuration: EcMotion.base,
    pageBuilder: (_, _, _) => screen,
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: EcMotion.easeOut);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}
