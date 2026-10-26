# Shared native video encoder setup

LastReel uses `cookoo_video_export` 0.1.0 from
[`cookoocode/cookoo_video_export`](https://github.com/cookoocode/cookoo_video_export/tree/f400124cb2540c56151cc3c4939cf36232427b7c)
(MIT, copyright COOKOO). The Git dependency in `app/pubspec.yaml` pins commit
`f400124cb2540c56151cc3c4939cf36232427b7c` from the
`codex/macos-video-export` branch. TextCrawl uses the same package; each app
keeps its own frame renderer, export controller, destinations and access rules.

## Setup

From `endcrawl/app`, run:

```sh
flutter pub get
```

The package and its revision are recorded in `app/pubspec.lock`. Flutter fetches
the public repository into its package cache for local development and CI. No
sibling folder or symlink is needed.

The plugin requires Flutter 3.44+, iOS 15+, macOS 12+ or Android API 24+.
Android builds use AGP 9's built-in Kotlin. The iOS and macOS Apple sources are
shared through `darwin/`; keep the existing iOS Podfile deployment-target floor.

When updating the encoder, commit and push the plugin first. Update the Git
`ref` in LastReel and TextCrawl to the same full commit SHA, run
`flutter pub get` and the export tests, and commit each app's lockfile.

## Validation

From `endcrawl/app`:

```sh
dart analyze lib test integration_test tool
flutter test test/features/export
flutter run -d macos
flutter test --no-pub integration_test/macos_export_test.dart -d macos
```

To run the package's contract tests, clone its repository and run
`flutter pub get --no-example` followed by
`flutter test --no-pub test/encoder_test.dart`. Its standalone example requires
a newer SDK than the plugin; see the example's `pubspec.yaml`.

LastReel's real-device export test is
`app/integration_test/native_export_test.dart`; use a disposable QA simulator
or an isolated test application ID because Flutter integration tests can remove
their test installation.
