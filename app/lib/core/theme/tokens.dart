import 'package:flutter/widgets.dart';

/// Size and motion tokens from the v2 design (Foundations). Colours and
/// type live in the theme extensions — [EcPalette] and [EcType] — read
/// through `context.palette` / `context.type`.
class EcRadius {
  EcRadius._();

  // "999 buttons · 18 cards · 16 rows · 12 inner · 28 sheets", fields 14.
  static const pill = 999.0;
  static const sheet = 28.0;
  static const hero = 22.0;
  static const group = 20.0;
  static const card = 18.0;
  static const row = 16.0;
  static const field = 14.0;
  static const inner = 12.0;
  static const tile = 10.0;
}

class EcMotion {
  EcMotion._();
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 250);

  // cubic-bezier(.2,.8,.2,1)
  static const easeOut = Cubic(0.2, 0.8, 0.2, 1);
  // cubic-bezier(.2,1.25,.35,1) — overshoots, spring-like.
  static const easeSpring = Cubic(0.2, 1.25, 0.35, 1);
}
