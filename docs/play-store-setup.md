# Google Play setup — 2026-09-27

App: Last Reel: End Credits Maker (`com.lastreel.app`).

## Current Console status

All initial app-information/store-listing tasks are completed. The owner added
store graphics, reviewer sign-in information and the privacy-policy URL, and
accepted the IARC terms. On 2026-09-27 the remaining declarations were saved:

- **Content ratings:** All Other App Types, in-app purchases, no random purchases,
  native user interaction, external content catalog or age-restricted products.
  IARC status Completed. ESRB Everyone, PEGI 3, USK All ages, IARC/Russia/Korea 3+;
  Brazil ClassInd 14+ as assigned by the questionnaire.
- **Target audience:** 13–15, 16–17, 18+, consistent with the owner's published
  policy and creator/student positioning.
- **Data safety:** completed; collected account name/email/user IDs, private
  project content, purchase history, approximate location, app interactions,
  diagnostics and device IDs. AdMob location/interactions/diagnostics/device IDs
  also disclosed as shared for advertising, analytics and fraud prevention.
  Account/project/subscription service-provider transfers not marked as sharing.
  All selected collection is persistent/non-ephemeral and required for the
  corresponding functionality. Account/purchase/project purposes follow the
  code and SDK guidance. Data encrypted in transit. No independent security
  certification claimed.
- **Account creation:** username/password and OAuth.
- **Privacy policy:** https://cookoo.dev/lastreel/privacy-policy
- **Account deletion:** https://cookoo.dev/lastreel/delete-account
- **Partial deletion:** https://cookoo.dev/lastreel/delete-account#partial
- Previously saved Ads Yes, Advertising ID Yes, no government/financial-service/
  health features, category Video Players & Editors, tag Video editing, public
  support email hello@cookoo.dev remain in place.

Changes are saved in Publishing overview, **not yet submitted for review**.
Google disables submission until release setup is complete. The existing closed
Alpha track has an old **1 (0.0.1)** draft, zero countries and no completed tester
selection. Do not submit that obsolete draft; prepare a current tested release
and choose the closed-test countries/tester group first. No rollout performed.

## Remaining release follow-ups

- Owner's published privacy/deletion pages omit RevenueCat. Add its handling of
  account-linked subscription/purchase records and the actual deletion/retention
  process. In-app Firebase deletion does not delete RevenueCat records.
- Current binary still has placeholder in-app legal/support content (see below).
- Real-device subscription purchase/restore checks remain pending.
- Closed-test release configuration and review submission remain pending.

## Listing copy

### Name

Last Reel: End Credits Maker

### Short description

Create cinematic rolling end credits with cast, crew, timing and video export.

### Full description

Give every name its moment.

Last Reel is an end credits maker for filmmakers, video creators and film students. Build a rolling credit sequence on your phone, preview the motion, and export it for your next film or video.

BUILD YOUR CREDITS
Start with a template or create your own sequence. Add title cards, cast and crew lists, departments, music credits, special thanks, dedications and closing cards. Reorder and duplicate blocks, or paste a list of names to speed up entry.

CONTROL THE ROLL
Set a target runtime or adjust the scroll speed. Fine-tune spacing, typography and background styling, then preview your credits as you edit. Readability and timing guidance helps you spot a roll that moves too quickly.

CHOOSE YOUR FORMAT
Create credits for widescreen, cinema, vertical and square projects. Choose your project frame rate and export H.264 or HEVC video on supported devices. PNG sequence export is available with Pro. Available codecs and maximum resolution depend on your device.

KEEP YOUR WORK TOGETHER
Sign in with Google or email to save and sync your projects. Autosave helps you keep editing without a manual save step.

FREE AND PRO
The free plan includes up to three projects, the credit editing tools, and video exports up to 1080p without a watermark. The app contains ads.

Optional LastReel Pro monthly or yearly subscriptions unlock unlimited projects, remove ads, and provide Pro export options, including PNG sequences and up to 4K on supported devices. Local prices and billing periods are shown in the app before purchase. Subscriptions renew automatically unless canceled through Google Play.

Questions or feedback? Contact hello@cookoo.dev.

## Data safety evidence (saved, awaiting review)

Code evidence is in `app/lib/data/repositories/`, `app/lib/features/ads/`,
`app/lib/features/export/`, and `app/lib/features/settings/controllers/`.
The in-app legal copy is explicitly marked placeholder and was not used as a
source for unverified promises.

| Data | Evidence / handling to disclose |
| --- | --- |
| Name, email, user ID | Firebase Auth (Google or email/password); required account identity. Firebase UID also identifies the RevenueCat customer. Account management and app functionality. |
| Other user-generated content | Credit names/text, project settings and project metadata stored in private per-user Firestore documents for project editing/sync. Persistent, not ephemeral. |
| Purchase history | RevenueCat verifies and retains subscription information. Its guidance requires collection, non-ephemeral handling, app functionality and analytics. Service-provider transfers alone do not mean sharing. |
| Approximate location | AdMob may infer it from IP address when ads are enabled; no GPS permissions found. |
| App interactions, diagnostics, device/other identifiers | AdMob's documented collection/sharing for advertising, analytics and fraud prevention. Final disclosure must match the enabled release and ad configuration. |
| Exported videos/images | Rendered locally; app does not automatically upload export files. User-directed sharing uses the system share sheet. Do not falsely declare all exported video as uploaded to the developer. |

No Firebase Analytics or Crashlytics dependency was found. Settings with those
names do not establish actual SDK collection. No health, contacts, calendar,
SMS or precise-location feature was found.

Sources consulted:
- https://developers.google.com/admob/android/privacy/play-data-disclosure
- https://www.revenuecat.com/docs/platform-resources/google-platform-resources/google-plays-data-safety

## Code/release follow-ups discovered

- Android AdMob app and five production units were verified and configured in
  the subsequent AdMob pass; debug/profile use test IDs. Release `0.0.3+4` includes this change and was built/signed for upload. AdMob approval/store linkage remains pending.
  See `admob.md`.
- `app/lib/core/config/app_links.dart` still contains placeholder support email
  `support@lastreel.app` and help URL. Align app support with `hello@cookoo.dev`
  and the final help URL in the next build. This pass changed Console metadata,
  not app binaries.
- In-app privacy policy and terms remain placeholder copy. Replace them with
  accurate owner-approved copy before production; don't promise unverified
  retention periods or that ad partners receive only country/app version.
- In-app account deletion removes Firebase Auth, Firestore projects/profile and
  local session references. It does not automatically delete RevenueCat's
  customer record; define the support/deletion process and retention policy.
- Real-device subscription purchase/restore testing is still pending; see
  `subscriptions.md`. Android native exports exclude ProRes, so the Play listing
  intentionally does not promise it.
