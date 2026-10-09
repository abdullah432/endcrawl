import 'package:flutter/widgets.dart';

/// The app's root navigator, for the rare UI that is raised by something
/// finishing in the background rather than by a tap — the rating prompt
/// after a render that ran with its sheet closed.
final rootNavigatorKey = GlobalKey<NavigatorState>();
