# LastReel subscriptions

## Configuration

Android package: `com.lastreel.app`. RevenueCat project: `796ef2dd`.
Public Android SDK key is in `app/lib/core/config/billing_config.dart`; it is a
client key, not a secret. Never put service-account JSON or secret REST keys in
Flutter assets, Dart defines, or source control.

| Setting | Value |
| --- | --- |
| Entitlement | `pro` |
| Default offering | `default` |
| Google subscription | `lastreel_pro` |
| Monthly base plan | `monthly`, auto-renewing, USD 4.99/month |
| Yearly base plan | `yearly`, auto-renewing, USD 29.99/year |
| Monthly RevenueCat product | `lastreel_pro:monthly` |
| Yearly RevenueCat product | `lastreel_pro:yearly` |
| Offering packages | `$rc_monthly`, `$rc_annual` |

Prices above were approved by the owner on 2026-09-27. The app displays localized
store prices fetched through RevenueCat, not these USD reference prices.

## Free trials (from 2026-10-01)

The free plan holds **two** projects (`Entitlement.freeProjectLimit`; raised from
one in the v3 handoff). Hitting the limit offers a free trial, not a purchase:
**7 days on monthly, 14 days on yearly** (yearly preselected). The library's plan
card (1.1a) has a single "Start free trial" button that opens 6.5, the only place
a plan is picked. A trial user is Pro. When a trial or Pro ends, nothing is
deleted: the two most recently edited projects stay editable, the others open
read-only (they still play and render), and ads come back.

**Store setup still to do** — the app reads trials from the store and shows the
plain price wherever none is offered, so nothing changes in code once these exist:

| Store | Where | What |
| --- | --- | --- |
| Google Play | Monetize → Subscriptions → `lastreel_pro` → base plan `monthly` → Add offer | Free trial, **7 days**, eligibility *New customer acquisition — never had this subscription* |
| Google Play | same, base plan `yearly` | Free trial, **14 days**, same eligibility |
| App Store | the monthly / yearly products → Subscription Prices → Introductory Offers | **Free**, 1 week / 2 weeks, new subscribers |

How the app reads them (`revenuecat_entitlement_repository.dart`):

- **Play** returns only the offers an account is eligible for; the trial length is
  the default option's free phase. An account that has had a trial gets none.
- **App Store** describes the trial as a free introductory price; the app asks
  `checkTrialOrIntroductoryPriceEligibility` and drops it for ineligible accounts.
- A trial shows as the `pro` entitlement with period type `TRIAL`; its expiry is
  the trial end (the "6 days left" countdown). An inactive `pro` means *lapsed*.

Analytics (Google Analytics): `trial_card_shown`, `trial_plan_selected{plan}`, `trial_started{plan, source}` (library, slots_full,
paywall, settings), and `trial_converted` / `trial_cancelled` inferred in the app.
For conversions and cancellations, prefer RevenueCat's Firebase integration, which
reports them from the store even when the app isn't running.

Test with a Play license tester: start each trial, check the countdown and the
"Free until …" date, cancel in the Play Store (Pro stays until the trial ends),
then let it expire and check that two projects stay editable.

## Runtime

`RevenueCatEntitlementRepository` owns the process-wide SDK and serializes account
changes, purchases, and restores. Firebase UID is the RevenueCat app user ID.
Sign-out/account switching clears visible access immediately; stale async results
cannot grant the previous customer's access to the next account. No plan is read
from client-writable Firestore fields.

Active `pro` entitlement controls unlimited projects, ad removal, and Pro exports.
Cancellation of auto-renewal does not revoke paid access early. The subscription
screen distinguishes renewal from expiry and opens the store management URL.
Store callbacks and foreground resume refresh status. Purchase cancellation is
silent; pending payment stays Free until confirmed. Missing offerings show a retry
state with no fabricated prices. Existing subscribers change plans in the store.

The app uses its own paywall, so no RevenueCat-hosted paywall is required.

## Build and test

```sh
cd app
flutter analyze
flutter test
flutter build appbundle --release
```

The current app version is `0.0.3+4` (version name `0.0.3`, version code `4`).
The signed release bundle was built on 2026-09-27 and copied to
`app/build/app/outputs/bundle/release/lastreel-0.0.3-4.aab`, ready for upload.
Its upload certificate matches the previously uploaded bundle. This build includes
the verified Android production AdMob configuration; it has not yet been uploaded.
Increment the version in `app/pubspec.yaml` before subsequent uploads. The generated signed
bundle is `app/build/app/outputs/bundle/release/app-release.aab`.

Install from the Play internal-test opt-in link with a Google account configured
as both an internal tester and a license tester. Verify monthly/yearly prices,
purchase confirmation, cancelled purchase, pending payment, restore after
reinstall, renewal, cancellation through the store, expiry, and switching Firebase
accounts. Confirm transactions and entitlement updates in RevenueCat sandbox.
A successful build and mocked tests do not establish real billing readiness.

## Account audit / remaining setup

Verified on 2026-09-27:

- RevenueCat Android app and service-account JSON already existed. Credentials
  now show **Valid credentials** after the billing-enabled build was uploaded.
  The existing service account already had the required app, financial-data,
  and order/subscription access; no permissions were changed.
- Created Google subscription `lastreel_pro` with **active** `monthly` and `yearly`
  auto-renewing base plans. US prices are USD 4.99 and USD 29.99 respectively.
  Both are available in 174 countries/regions with Play-generated regional
  prices. Monthly is Play's backwards-compatible base plan. No trial or offer
  was added at the time; see "Free trials" above for the offers now needed. Default grace periods are 7 days monthly and 14 days yearly, with
  automatic account hold and resubscribe enabled.
- Both RevenueCat product mappings are attached to `pro` and assigned to the
  default offering's monthly/annual packages.
- Enabled Play real-time developer notifications for subscriptions and voided
  purchases using the existing topic
  `projects/endcrawl-620c2/topics/Play-Store-Notifications`. Sent a test event;
  RevenueCat confirmed receipt at 2026-09-27 11:21 UTC. Play confirmed the
  configuration was saved.
- The owner uploaded the signed `0.0.2+3` Android bundle. Play release details
  confirm artifact **3 (0.0.2)** is available to internal testers, although the
  release's display title still says `2 (0.0.1) - subscription integration`.
  Local manifest version and JAR signature were verified. The versioned file is
  `app/build/app/outputs/bundle/release/lastreel-0.0.2-3.aab`.
- The internal test track is **Active**. A dedicated `LastReel billing testers`
  list containing the owner-provided test account is selected. That account is
  also already a license tester through the existing `Internal Tester` list;
  developer-wide license-testing settings were left unchanged.
  Opt-in URL: https://play.google.com/apps/internaltest/4701406286058635279
- Real store purchase/restore testing remains required. No Android device was
  connected during this session. Verify license-test access before attempting
  purchases, and use the Play test payment method.

## iOS

No App Store connection or public iOS SDK key was available in this RevenueCat
project. iOS therefore keeps purchases unavailable until configured with
`--dart-define=REVENUECAT_IOS_API_KEY=appl_...` and matching App Store products
attached to the same entitlement/offering. Do not use the Android or Test Store
key in an iOS release.

Existing committed conflict markers remain in `ios/Podfile.lock` and
`ios/Runner.xcodeproj/project.pbxproj`; iOS native build validation is outstanding.
The Android Firebase JSON had similar committed conflicts; they were resolved
using the current `com.lastreel.app` configuration to unblock the Android build.

## References

- https://www.revenuecat.com/docs/getting-started/installation/flutter
- https://www.revenuecat.com/docs/getting-started/configuring-sdk
- https://www.revenuecat.com/docs/service-credentials/creating-play-service-credentials
