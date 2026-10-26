# LastReel for macOS

The macOS target uses the same Flutter application, project models, editor,
renderer and access rules as mobile and web. It requires macOS 12 or later and
Xcode with a signed-in COOKOO development team (`UA47GB93N8`). `flutter pub get`
downloads the [shared video encoder](shared-video-export.md) at its pinned
Git revision.

## Run locally

```sh
cd /Users/hashir/endcrawl/app
flutter pub get
flutter devices
flutter run -d macos
```

To make a signed local debug app:

```sh
flutter build macos --debug
```

The app is at `app/build/macos/Build/Products/Debug/LastReel.app`. Xcode may
ask to register a new Mac or create a development provisioning profile the
first time it builds. The Runner target uses bundle ID `com.lastreel.app` and
the COOKOO team. Its sandbox permits network access, Apple and Google sign-in,
and saving exports to a file the user chooses.

## Access and exports

- Sign in with the same LastReel account used on mobile. Desktop editing and
  exporting require Pro verified by the server. Free accounts can preview
  projects and are directed to a mobile subscription. The mobile Free plan is
  unchanged; its tester switch cannot unlock desktop operations.
- The desktop editor uses the existing responsive wide layout. Closing or
  resizing a window does not create a separate project or export state.
- H.264, HEVC, ProRes and PNG sequences use the existing export controller. The
  shared Darwin encoder supplies the video formats; the existing Dart PNG
  encoder supplies ZIP sequences. On the Ready sheet, **Save to Mac** opens a
  native save dialog. No mobile Photos or AdMob UI is shown on macOS.

## Checks

```sh
flutter test --no-pub test/features/access/macos_access_test.dart
flutter test --no-pub test/features/export/png_sequence_encoder_test.dart
flutter test --no-pub integration_test/macos_export_test.dart -d macos
dart analyze lib integration_test/macos_export_test.dart test/features/access/macos_access_test.dart
```

The native integration test renders real frames through each supported codec
and checks cancellation. It uses temporary test files and never signs in or
writes to Photos.

For distribution outside this Mac, configure the intended macOS distribution
certificate, provisioning profile and notarization or Mac App Store delivery
in Apple Developer/Xcode. The development signing used by `flutter run` does
not publish or notarize a build.
