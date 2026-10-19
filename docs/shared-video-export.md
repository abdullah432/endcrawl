# Shared native video encoder setup

LastReel's native adapter uses the private `cookoo_video_export` 0.1.0 package.
The source is tracked in
[`abdullah432/starcrawler/vendor/cookoo_video_export`](https://github.com/abdullah432/starcrawler/tree/c7d6e0581b48bad1584053254b002595af49d230/vendor/cookoo_video_export),
commit `c7d6e0581b48bad1584053254b002595af49d230` (MIT, copyright COOKOO).

Keep `endcrawl` and `shared_packages` beside one another. From `endcrawl/app`,
the existing dependency resolves to `../../shared_packages/cookoo_video_export`.
Use one source checkout for both apps; LastReel keeps its own frame renderer,
export controller, destinations and access rules.

## First setup on macOS or Linux

Git access to the private `abdullah432/starcrawler` repository is required.
For a checkout at `$HOME/endcrawl`, run these commands once. If a shared encoder
folder already exists, inspect it before changing or replacing it.

```sh
mkdir -p "$HOME/shared_packages"
git clone --filter=blob:none --sparse --depth 1 --branch master \
  https://github.com/abdullah432/starcrawler.git \
  "$HOME/shared_packages/.cookoo-video-export-source"
git -C "$HOME/shared_packages/.cookoo-video-export-source" sparse-checkout set vendor/cookoo_video_export
git -C "$HOME/shared_packages/.cookoo-video-export-source" fetch --depth 1 origin c7d6e0581b48bad1584053254b002595af49d230
git -C "$HOME/shared_packages/.cookoo-video-export-source" checkout --detach c7d6e0581b48bad1584053254b002595af49d230
ln -s .cookoo-video-export-source/vendor/cookoo_video_export \
  "$HOME/shared_packages/cookoo_video_export"
cd "$HOME/endcrawl/app"
flutter pub get
```

The symlink points to the tracked source. For another checkout location, use
its parent instead of `$HOME`. CI needs the same
sibling layout and repository access before running `flutter pub get`.

Requires Flutter 3.44+, iOS 15+ and Android API 24+. Android builds use AGP 9's
built-in Kotlin. Keep the existing iOS Podfile deployment-target floor.

## Validation

From `endcrawl/app`:

```sh
dart analyze lib test integration_test tool
flutter test test/features/export/native_video_encoder_test.dart
flutter run -d DEVICE_ID
```

To run the package's contract tests on Flutter 3.44, use `flutter pub get
--no-example` and `flutter test --no-pub test/encoder_test.dart` from the shared
package directory. Its standalone example requires a newer SDK than the plugin.

LastReel's real-device export test is
`app/integration_test/native_export_test.dart`; use a disposable
QA simulator or an isolated test application ID because Flutter integration
tests can remove their test installation.
