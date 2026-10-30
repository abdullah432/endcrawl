# AdMob configuration

Verified against the live AdMob account on 2026-09-27.

App: **Last Reel: End Credits Maker — Android**.
App ID: `ca-app-pub-6644211975790806~5643195524`.

| Placement | Format | Production ad unit |
| --- | --- | --- |
| Library | Native advanced | `ca-app-pub-6644211975790806/6465497619` |
| Editor (`editor_screen_native_ad`) | Native advanced | `ca-app-pub-6644211975790806/6890805343` |
| Timing & Look (`timing_look_screen_native_ad`) | Native advanced | `ca-app-pub-6644211975790806/2251596457` |
| Render the roll (tablet settings) | Native advanced | `ca-app-pub-6644211975790806/7487430088` |
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
| Editor (`editor_screen_native_ad`) | Native advanced | `ca-app-pub-6644211975790806/1830050359` |
| Timing & Look (`timing_look_screen_native_ad`) | Native advanced | `ca-app-pub-6644211975790806/9235632198` |
| Render the roll (tablet settings) | Native advanced | `ca-app-pub-6644211975790806/8861677778` |
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

Native tablets (the iOS and Android apps, shortest side ≥ 600, at any width —
a 13" iPad in landscape included) follow tablet handoff A.
Ad slot names in analytics are `library_foot`, `export_settings_foot`, `render_wait`, `editor_foot`,
`timing_look_foot` and `rewarded_pro_render`.

| Slot | Where | Unit | Layout |
| --- | --- | --- | --- |
| `library_foot` | Foot of the Projects tab, at 0, 1 and 2 of 2 | Library | `strip` / `stripPortrait` |
| `export_settings_foot` | Bottom of the “Render the roll” settings page, before rendering, in both tablet orientations | Render the roll | `strip` / `stripPortrait` |
| `render_wait` | Under the progress card on the render page (T6.2, P6.2), only while the render runs | Rendering | `strip` / `stripPortrait` |
| `editor_foot` | Its own card under the editor's block list, apart from + Block and Paste (T3.1); at the bottom edge upright (P3.1). Hidden while the keyboard is up | Editor | `compact` / `stripPortrait` |
| `timing_look_foot` | Under the Timing & Look panel, in the same place on both tabs (T5.1, T5.2); at the bottom edge upright (P5.1, P5.2) | Timing & Look | `compact` / `stripPortrait` |

Settings carries no ads at all (T8.3): the old tablet Settings units now
serve Timing & Look.

Both native factories
(`NativeAdFactory.kt`, `NativeAdFactory.swift`) draw the tablet shapes from
`customOptions["layout"]`, and the Dart card around them adds "Remove ads".
Each slot reserves its height while
loading and closes up if nothing fills it. Only the visible tab requests its
ad, and the tablet shows no native ad once a render is ready.

The export interstitial follows the phone: shown once a render succeeds, never
on the Export action — "Export…" from the tablet's project menu opens the
export page directly too.

The AdMob console name `render_the_rool_screen_native` maps to
`AdPlacement.exportSettings` → `AdUnits.exportSettingsNative`. Its Android and
iOS production IDs above were supplied on 2026-10-22. This is separate from
`renderingNative`, which is used while encoding. The settings footer uses the
same native ad component as the home screen, with the existing Free/Pro and
consent checks. It appears on Android tablets and iPads only, never on phones.
Debug/profile builds continue to use test IDs.

## When an ad is visible

- Free accounts show native ads in the library, the tablet editor and Timing & Look, tablet export settings, rendering and ready views.
  A full Free library intentionally replaces its ad with the upgrade card.
- Pro, trials and the native tester Pro override show no ads.
- Settings shows no ads, on any device or plan.
- On Android and iOS Free, the interstitial is preloaded when the editor opens
  (and again when a render starts) and shown once a render finishes
  successfully, with its file already on the ready screen — whether the
  export page is open or the user chose "Keep working". Each platform uses its
  supplied `export_success_interstitial` unit. Tapping Export, failure,
  cancellation and saving/sharing never show it; a retry that succeeds does.
  A render unlocked by the rewarded ad shows no second ad. Web and Pro do not
  request it. Tester Pro also suppresses ads: turn off Settings → LastReel Pro
  (tester) to verify Free ads on a simulator.
- Only a loaded ad is shown; the ready screen never waits for inventory. A
  request that finishes later is kept for the next render and never opens an
  ad over the current one. The rating question waits for the ad to close.
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

## TestFlight and App Store testing devices

TestFlight uses release configuration; installing through TestFlight does not
by itself make ads test ads. For an installed TestFlight or App Store build,
register the iPhone under AdMob → Settings → Test devices with its **IDFA**.
The USB/Xcode UDID and the SDK's hashed test-device identifier are different
identifiers and must not be entered as the IDFA.

The connected iPhone 13 Pro was registered in the AdMob account as
`iPhone 13 device` on 2026-10-22 using its IDFA after tracking permission was
authorized. Device identifiers are kept in AdMob, not in this repository.
Keep tracking permission enabled for IDFA-based test-device recognition.

Google documents up to 24 hours for a new registration to take effect. Confirm
the **Test Ad** badge before interacting with an ad. Registration covers AdMob
Network ads; mediated networks require their own test-mode setup. Debug/profile
builds already use Google's sample ad units.

Reference: [Google's test-device setup](https://support.google.com/admob/answer/9691433).

## Simulator smoke check

```sh
cd app
flutter run -t tool/ad_smoke.dart -d <simulator-id>
```

This debug/profile-only entry point renders the configured native placements with
Google's sample inventory and preloads an app-open test ad. It uses the same
consent flow and native factory as the app, without reading or changing any
account/project data. Console messages distinguish consent, initialization,
load failures and successfully loaded ads. Restore the product entry point
afterward with `flutter run -t lib/main.dart -d <simulator-id>`. On a physical
iPhone, `flutter run --profile -t tool/ad_smoke.dart -d <device-id>` also uses
sample inventory and can run without a debugger.

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

## App Tracking Transparency (iOS)

Free iOS users see a short pre-prompt ("Keep LastReel free, with ads that
fit.", `lib/features/tracking/`) before Apple's tracking alert. It shows once:
on the first app open at least three days after the first launch on the device
(recorded in `install_first_seen_at`; a device updating to this build counts
from the update), over the library, never mid-edit and never in the same
session as the desk invite or the rating prompt. Pro is never asked. If iOS has
already decided, it never shows. Its one action, Continue, opens the system
alert, whose purpose string is `NSUserTrackingUsageDescription` in
`Info.plist`.

On iOS, personalised ads follow the ATT answer, and Privacy & data shows it as
a status row that opens iOS Settings (or asks, if iOS hasn't yet). Android keeps
the Personalised ads switch. Analytics: `att_preprompt_shown`,
`att_preprompt_continue`, `att_result{status}`.

Before shipping, check that the promises hold: the number of ads doesn't change
with the tracking answer, and project text is never sent to the ad SDK.
