import 'dart:io';

/// Run from app/ after `dart run flutter_launcher_icons`. These website
/// assets are derived from the same master as the iOS, Android and PWA icons.
void main() {
  const files = {
    'web/icons/Icon-512.png': '../website/app/icon.png',
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png':
        '../website/app/apple-icon.png',
    'web/icons/Icon-192.png': '../website/assets/brand/app-icon.png',
  };
  for (final entry in files.entries) {
    final target = File(entry.value);
    target.parent.createSync(recursive: true);
    File(entry.key).copySync(target.path);
    stdout.writeln('Updated ${target.path}');
  }
}
