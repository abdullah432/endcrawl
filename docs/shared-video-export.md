# Shared native video encoder setup

LastReel's native adapter uses `cookoo_video_export` 0.1.0 from
[`cookoocode/cookoo_video_export`](https://github.com/cookoocode/cookoo_video_export)
(MIT, copyright COOKOO). TextCrawl uses the same package. LastReel keeps its own
frame renderer, export controller, destinations and access rules.

## Setup

From `endcrawl/app`, run:

```sh
flutter pub get
```

The Git dependency in `pubspec.yaml` pins a full commit SHA, and `pubspec.lock`
records the same resolved revision. Flutter fetches the public repository into
its package cache and registers the plugin on Android and iOS. Local development
and CI use this same command; no sibling folder, sparse checkout or symlink is
required.

Requires Flutter 3.44+, iOS 15+ and Android API 24+. Android builds use AGP 9's
built-in Kotlin. Keep the existing iOS Podfile deployment-target floor.

When updating the encoder, commit and push the plugin first. Update the Git
`ref` in both LastReel and TextCrawl to the same full commit SHA, run
`flutter pub get` and the export tests, and commit each app's lockfile.

## Validation

From `endcrawl/app`:

```sh
dart analyze lib test integration_test tool
flutter test test/features/export
flutter run -d DEVICE_ID
```

To run the package's contract tests, clone its repository and run
`flutter pub get --no-example` followed by
`flutter test --no-pub test/encoder_test.dart`. Its standalone example requires
a newer SDK than the plugin; see the example's `pubspec.yaml`.

LastReel/Endcrawl's real-device export test is
`app/integration_test/native_export_test.dart`; use a disposable
QA simulator or an isolated test application ID because Flutter integration
tests can remove their test installation.
