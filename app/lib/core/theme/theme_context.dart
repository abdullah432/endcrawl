import 'package:flutter/material.dart';

import 'ec_palette.dart';
import 'ec_type.dart';

/// `context.palette.ink`, `context.type.caption` — the only way screens read
/// colour and type. Falls back to the light values so a widget pumped in
/// isolation (a test, a preview) still renders.
extension EcThemeContext on BuildContext {
  EcPalette get palette => Theme.of(this).extension<EcPalette>() ?? EcPalette.light;
  EcType get type => Theme.of(this).extension<EcType>() ?? EcType.from(palette);
}
