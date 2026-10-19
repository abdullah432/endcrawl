# LastReel logo assets

The approved 1024×1024 square logo supplied on 2026-10-19 is the master at
`app/assets/icon/app_icon.png`. Keep it square with a full background;
platform launchers apply their own icon masks. The supplied smaller rounded
preview is not used as a native launcher icon.

Regenerate from the repository's existing icon generator:

```sh
cd app
dart run flutter_launcher_icons
dart run tool/sync_brand_assets.dart
```

This updates iPhone/iPad AppIcon sizes, Android launcher densities, Flutter
web favicon and PWA icons, and the Next.js icon, Apple touch icon and brand
mark. `EcLogo` and the website's `Wordmark` use that same artwork.

Native launcher changes appear after installing a newly built app. Website
and Flutter web changes require their normal hosting deployment. Regeneration
does not publish an app or deploy hosting.
