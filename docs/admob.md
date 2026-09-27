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

`AdUnits.current` selects production units only in Android release mode.
Debug/profile Android and iOS builds use Google's sample units. Gradle injects
Google's sample Android app ID into debug/profile manifests and the verified
app ID into release. These app/unit IDs are public identifiers, not secrets.

The old code incorrectly assigned these Android IDs to iOS. That mapping has
been removed. iOS release ads stay disabled until a separate iOS AdMob app and
units are available; its Info.plist now uses the sample iOS app ID, with no
production ad requests. Unsupported desktop platforms return no units.

The reviewed account shows **Requires review**, no linked store details and no
app/ad-unit frequency caps. No account settings were changed and no live ads
were requested or clicked. Actual ad delivery remains subject to AdMob approval,
consent and inventory. Existing Pro/consent gates are unchanged.

Android release `0.0.3+4` includes these changes and is built, signed and ready
for upload at `app/build/app/outputs/bundle/release/lastreel-0.0.3-4.aab`.
The previously uploaded `0.0.2+3` bundle predates them.
