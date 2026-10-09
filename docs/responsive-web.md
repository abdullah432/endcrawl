# Responsive app and Pro web access

The mobile app keeps its existing Free/Pro rules, purchasing, controllers, models,
autosave, playback and rendering engine. Web is a Pro workspace: signed-in Free
accounts can see the app behind a single access gate, but cannot edit, create,
play, export or invoke other workspace actions. Sign-in, subscription recheck,
mobile download and sign-out remain available. There is no browser checkout,
Stripe integration, web advertising path or new usage quota.

## Presentation

`core/layout/adaptive_layout.dart` selects layouts from available logical width:

| Width | Presentation |
| --- | --- |
| Below 600 | Existing compact mobile composition |
| 600–767 | Spacious single column |
| 768–1279 | Tablet: monitor/tools left, block list right |
| 1280+ | Desktop: 264px list, flexible monitor/timeline, 328px inspector |

Tablet uses 20px outer gutters, a 16px gap and a list clamped to 280–372px.
Short windows retain their width-selected composition and scroll. The editor
route and providers stay mounted; keyed form bodies retain unfinished input when
moving between panes. Block/Paste sit beside the list; Timing/Export are in the
toolbar. Look and Background remain accessible from the monitor. The shared
forms use host-owned completion callbacks instead of popping the editor route.

Authentication caps at 480px, general forms at 640px, settings/legal at 800px;
library cards use a grid with a 320px minimum width and 16px gaps. Space toggles
playback and arrows step frames when focus is outside text entry and dialogs.
Timeline ranges come from the existing engine segments and measurements; zoom
changes only their display. Native phone landscape uses the physical display's
shortest logical dimension. Browser resizing never opens fullscreen playback.

The supplied Tablet/Desktop HTML files were used as visual references for pane
composition, monitor placement, typography and the standing timing report.
Existing branding and product rules remain authoritative; embedded migration
instructions and inactive prototype controls were not adopted.

## Browser exports

The existing export controller and `FrameRenderer` use conditional encoder and
output adapters. `ExportArtifact` identifies a native cache file or browser
storage handle. H.264 uses WebCodecs through the locally bundled Mediabunny
1.61.3 module. HEVC and ProRes remain native-only. PNG ZIP creation is shared by
native and web, with incremental output, sequential filenames and alpha.

Each H.264 start probes the selected dimensions, rational frame rate and bitrate
before rendering. Frame delivery awaits encoding/storage, and frames are closed
promptly. OPFS output streams to origin-private storage; browsers without it use
a bounded 64 MiB memory sink. Unsupported encoding and storage/quota failures
show recoverable errors. Lower-resolution retry is available. Hidden tabs pause
the shared rendering loop and resume without skipping frames.

Completed browser output has an explicit Download action and Share only when the
browser supports file sharing. Cancellation, replacement, sign-out and controller
disposal discard temporary output; pagehide also requests cleanup. Browser
termination can interrupt asynchronous pagehide cleanup, so a hard crash is not
a guaranteed cleanup boundary. Native Photos and sharing destinations remain.

Regenerate the checked-in bundle after changing its source:

```sh
cd app/web/export_bridge
npm ci
npm test
npm run build
```

Serve web over HTTPS (localhost is suitable for development). Keep
`export_bridge.js`, its linked license notices and the notice/source link in
`web/export_bridge/NOTICE.txt` together. Mediabunny is MPL-2.0 licensed; the
dependency and its integrity hash are pinned in the package lock.

## Subscription synchronization: required deployment configuration

Native RevenueCat continues to identify customers with their Firebase UID.
Web watches the server-owned `billingEntitlements/{uid}` document and refreshes
on sign-in, foreground resume and manual recheck. Account changes clear access
immediately. Initial checking is neutral; temporary failures retain verified
access only through its recorded expiry. Firestore rules allow each user to
read their own ledger and deny all client writes.

`functions/` contains Node 22 TypeScript functions in `us-central1`:

- `refreshEntitlement`: authenticated callable; account ID comes from Auth.
- `revenueCatWebhook`: authenticated HTTP endpoint; durably enqueues each event
  ID once in `billingWebhookEvents`.
- `reconcileBillingEvent`: retryable internal Firestore worker; reconciles both
  sides of transfers and other affected Firebase accounts.

Callable and worker fetch canonical RevenueCat customer information through the
same reconciler. Event payloads never directly grant access. A Firestore
transaction rejects older canonical results. The ledger contains schema version,
plan, billing period, expiry, trial expiry, renewal status, store management URL,
lapsed status and verification/source timestamps.

No functions, rules or hosting were deployed during implementation. Configure a
staging project first, with billing enabled for Functions and matching Firebase
client configuration. From the repository root:

```sh
npm --prefix functions ci
npm --prefix functions test
firebase functions:secrets:set REVENUECAT_SECRET_API_KEY --project YOUR_PROJECT
firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH --project YOUR_PROJECT
firebase deploy --only functions,firestore:rules --project YOUR_PROJECT
```

Enter secrets interactively; never place them in Dart defines or Flutter assets.
The API key must be a RevenueCat secret REST key with customer-read access for
the existing mobile project. In RevenueCat, configure the deployed
`revenueCatWebhook` URL and set its Authorization header to the **exact** value
stored in `REVENUECAT_WEBHOOK_AUTH` (including `Bearer ` if you chose that prefix).
Send subscription events, refunds, expirations and transfers. Keep customer IDs
aligned with Firebase UIDs. Ensure the callable and Firestore worker both deploy.

The handoff uses the existing verified Android listing and a QR code on desktop.
iOS says Coming soon unless a real `IOS_APP_STORE_URL` is supplied at build time.
Web displays no unverified price or promised trial eligibility. Existing Pro
users receive the originating store's management link. Rechecking unlocks the
workspace only after verified Pro access is emitted.

Emulator validation (Java and Firebase CLI required):

```sh
firebase emulators:exec --only firestore --project demo-lastreel \
  'npm --prefix functions test'
```

The tests cover account isolation, denied self-grants, trials, renewal,
cancellation, grace, expiry, refunds, transfer accounts, duplicate reconciliation,
delayed results and a failed fetch preserving the last verified document.

## Verification and remaining release checks

Local validation on 2026-10-09:

- Flutter analysis: no issues. Full suite: 366 passed, 5 skipped.
- Android debug, iOS simulator and web release builds passed. iOS retains the
  existing Swift package integration, enabled in the project manifest.
- Browser storage tests: 4 passed. Backend unit/emulator suite: 4 passed.
- Widget layouts cover 599/600, 767/768, 1279/1280, 834×1194, 1194×834,
  1440×900, short panes, enlarged text, keyboard insets and draft preservation
  through tablet → desktop → compact resizing.
- Chrome, Firefox and WebKit encoded downloadable H.264 at 24 and 30000/1001 fps,
  with OPFS and forced memory fallback. Disabling WebCodecs offers PNG honestly.
- The actual Flutter renderer/controller produced a 1920×1080 MP4 with 25 frames
  at 24 fps and duration 1.041667s. Its alpha PNG ZIP contains 25 ordered
  1280×720 RGBA images with transparent corners and visible text.

Reference and implementation screenshots, MP4 samples and the PNG ZIP are under
`output/playwright/`; see its [reference comparisons](../output/playwright/README.md).
The reusable bridge check is
`app/web/export_bridge/test/browser-checks.js`; load the running app in a browser
and execute it with the Playwright CLI's `run-code` command. The development-only
entrypoint `app/test/responsive_preview.dart` uses in-memory repositories while
exercising the real renderer, browser encoder and destinations:

```sh
cd app
flutter run -d web-server --web-port=8773 -t test/responsive_preview.dart
```

Use `?short=1` for a short render or `?plan=free` for the blocked preview.
Production builds use `lib/main.dart` and real repositories.

WebKit testing is engine coverage, not a shipping Safari check. Edge and actual
Safari still need release validation, including downloads, sharing and codec
fallback on supported target versions. Native renders need real-device playback
checks. Production readiness also requires deployed Functions/rules/secrets,
RevenueCat webhook configuration and a real mobile purchase → same-account web
access → cancellation/expiry test. No project-schema migration or native desktop
target was introduced.

References: [Flutter adaptive layout](https://docs.flutter.dev/ui/adaptive-responsive/general),
[orientation restrictions](https://api.flutter.dev/flutter/services/SystemChrome/setPreferredOrientations.html),
[Mediabunny output](https://mediabunny.dev/guide/writing-media-files),
[RevenueCat webhook reconciliation](https://www.revenuecat.com/docs/integrations/webhooks).
