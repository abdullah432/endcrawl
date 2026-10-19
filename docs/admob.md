# AdMob configuration

Verified against the live AdMob account on 2026-09-27.

App: **Last Reel: End Credits Maker — Android**.
App ID: `ca-app-pub-6644211975790806~5643195524`.

| Placement | Format | Production ad unit |
| --- | --- | --- |
| Library | Native advanced | `ca-app-pub-6644211975790806/6465497619` |
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
| Rendering | Native advanced | `ca-app-pub-6644211975790806/8683033622` |
| Export ready | Native advanced | `ca-app-pub-6644211975790806/2333072682` |
| Pro export reward | Rewarded interstitial | `ca-app-pub-6644211975790806/9584876749` |
| Resume | App open | `ca-app-pub-6644211975790806/2740441803` |

`AdUnits.current` selects each platform's production units only in release
mode. Debug/profile Android and iOS builds use Google's sample units and app
IDs. On iOS, `Info.plist` reads `ADMOB_APP_ID` from the build configuration;
Android uses the `admobAppId` manifest placeholder. Unsupported desktop/web
builds have no AdMob units. These identifiers are public, not secrets.

## When an ad is visible

- Free accounts show native ads in the library, rendering and ready views.
  A full Free library intentionally replaces its ad with the upgrade card.
- Pro, trials and the native tester Pro override show no ads.
- On Android Free, an interstitial is preloaded when a render starts and shown
  once after encoding finishes successfully and the output is available. The
  supplied unit is Android-only. Failed/cancelled renders, iOS and web do not
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

## Simulator smoke check

```sh
cd app
flutter run -t tool/ad_smoke.dart -d <simulator-id>
```

This debug-only entry point renders the three real native placements with
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
