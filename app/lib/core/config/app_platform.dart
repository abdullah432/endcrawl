import 'package:flutter/foundation.dart';

/// Platform capabilities are independent of a window's current size.
abstract final class AppPlatform {
  static bool get isNativeDesktop =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        _ => false,
      };

  /// Desktop and web use the existing server-verified mobile subscription.
  static bool get requiresVerifiedPro => kIsWeb || isNativeDesktop;

  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
}
