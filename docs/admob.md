# AdMob configuration

Verified against the live AdMob account on 2026-09-27.

App: **Last Reel: End Credits Maker — Android**.
App ID: `ca-app-pub-6644211975790806~5643195524`.

| Placement | Format | Production ad unit |
| --- | --- | --- |
| Library | Native advanced | `ca-app-pub-6644211975790806/6465497619` |
| Tablet Settings | Native advanced | `ca-app-pub-6644211975790806/2251596457` |
| Rendering | Native advanced | `ca-app-pub-6644211975790806/7706337805` |
| Export ready | Native advanced | `ca-app-pub-6644211975790806/4888602772` |
| Pro export reward | Rewarded interstitial | `ca-app-pub-6644211975790806/1799405002` |
| Resume | App open | `ca-app-pub-6644211975790806/6421176298` |
| Successful export | Interstitial | `ca-app-pub-6644211975790806/4830936025` |

## iOS

App ID supplied for LastReel iOS: `ca-app-pub-6644211975790806~3747523873`.

| Placement | Format | Production ad unit |
| --- | --- | --- |
| Library | Native advanced | `ca-app-pub-6644211975790806/7231930165` |
| iPad Settings | Native advanced | `ca-app-pub-6644211975790806/9235632198` |
| Rendering | Native advanced | `ca-app-pub-6644211975790806/8683033622` |
| Export ready | Native advanced | `ca-app-pub-6644211975790806/2333072682` |
| Pro export reward | Rewarded interstitial | `ca-app-pub-6644211975790806/9584876749` |
| Resume | App open | `ca-app-pub-6644211975790806/2740441803` |
| Successful export | Interstitial | `ca-app-pub-6644211975790806/7459691102` |

`AdUnits.current` selects each platform's production units only in release
mode. Debug/profile Android and iOS builds use Google's sample units and app
IDs. On iOS, `Info.plist` reads `ADMOB_APP_ID` from the build configuration;
Android uses the `admobAppId` manifest placeholder. Unsupported desktop/web
builds have no AdMob units. These identifiers are public, not secrets.

## Tablet slots

Native Android tablets (shortest side ≥ 600, medium layout) follow the tablet
handoff A (`design/` brief, §5). Ad slot names in analytics are `library_foot`,
`settings_list`, `render_wait` and `rewarded_pro_render`.

| Slot | Where | Unit | Layout |
| --- | --- | --- | --- |
| `library_foot` | Foot of the Projects tab, at 0, 1 and 2 of 2 | Library | `strip` / `stripPortrait` |
| `settings_list` | Under the Settings section list; end of the portrait Settings page | Library (until a dedicated unit exists) | `compact` |
| `render_wait` | Under the render progress | Rendering | phone row |

`AdUnits.settingsNative` reuses the library unit; create a dedicated native
unit in AdMob and set it there to report the Settings slot separately. The
Android factory (`NativeAdFactory.kt`) draws the tablet shapes from
`customOptions["layout"]`; the Dart card around them adds "Remove ads". iOS keeps
its row until iPad ships. Each slot reserves its height while loading and
closes up if nothing fills it. Only the visible tab requests its ad, and the
tablet shows no ad once a render is ready.

## When an ad is visible

- Free accounts show native ads in the library, rendering and ready views.
  A full Free library intentionally replaces its ad with the upgrade card.
- Pro, trials and the native tester Pro override show no ads.
- Settings has a native placement on Free iPads and Android tablets only,
  below the detail content, using the existing native factory and consent
  flow. Tablet detection uses the display's shortest side (600 logical pixels)
  so an iPad keeps the placement in a narrow split-view window. Phones,
  desktop apps and web do not request it; no fill leaves no blank frame.
- On Android and iOS Free, an interstitial is preloaded when a render starts
  and shown once after encoding finishes successfully and the output is available. The
  appropriate platform's unit is used. Failed/cancelled renders and web do not
  show this placement. Saving/sharing or reopening the ready screen does not
  trigger another impression.
- An unavailable, loading, expired or failed interstitial leaves the ready
  screen usable. Requests that finish later never open an ad unexpectedly.
  Ads are skipped while backgrounded or while another full-screen ad is open;
  returning from the app's own ad does not stack an app-open ad.
- The rating question temporarily replaces the rendering/ready native slot.
- App-open ads are preloaded on Free, and displayed only on a return from
  the background with an ad ready. They never appear on cold launch.
- UMP must allow requests before SDK initialization. Cached permission can
  start ads while consent refreshes; a first-launch consent error stays
  closed. Failed startup/native/app-open requests get at most three attempts
  with delays of 30 and 60 seconds. Native slots can also recover on resume.
- A native slot has no empty sponsored frame while loading or after no fill.

## Android release build

Run tests to completion before starting the release build, then use
`flutter build apk --release` from `app/` (with the intended Android
`--build-name` and `--build-number`). Allow Flutter to regenerate platform
tooling: using `--no-pub` after tests can retain the test plugin registrant
and fail release compilation because `integration_test` is not packaged.

## Simulator smoke check

```sh
cd app
flutter run -t tool/ad_smoke.dart -d <simulator-id>
```

This debug-only entry point renders the four real native placements with
Google's sample inventory and preloads an app-open test ad. It uses the same
consent flow and native factory as the app, without reading or changing any
account/project data. Console messages distinguish consent, initialization,
load failures and successfully loaded ads. Restore the product entry point
afterward with `flutter run -t lib/main.dart -d <simulator-id>`.

Google's [test-ad guide](https://developers.google.com/admob/flutter/test-ads)
and [UMP guide](https://developers.google.com/admob/flutter/privacy) describe
test inventory and the two consent checks used here.

The Android account review on 2026-09-27 showed **Requires review**, no linked store details and no
app/ad-unit frequency caps. No account settings were changed and no live ads
were requested or clicked. Actual ad delivery remains subject to AdMob approval,
consent and inventory. Existing Pro/consent gates are unchanged.

The current iOS AdMob app's approval, consent messages and production fill
must be checked in its own AdMob console; the IDs alone do not verify those
settings. Debug simulator checks use sample inventory.
