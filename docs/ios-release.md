# iOS release checklist

For the free iOS launch (`IOS_FREE_LAUNCH=true`, the default): no
subscriptions, a paywall or a Subscription page on iPhone and iPad; Free shows
ads after the first-Home ATT decision. The neutral explanation has one Continue
button, followed by the native iOS permission alert.

## Version

Pass the iOS version explicitly when `pubspec.yaml` is set to an Android
release. Build 10 was rejected for ITMS-91064, fixed in build 11. Build 12 addresses
Guideline 2.1 by removing the three-day ATT delay and gating ad initialization.
Every later upload needs a higher build number.

```sh
python3 tool/validate_privacy_manifests.py ios/Runner/PrivacyInfo.xcprivacy
flutter build ipa --release --target=lib/main.dart --build-name=1.0.2 --build-number=12 \
  --dart-define=AD_DIAGNOSTICS=false --dart-define=AD_NATIVE_TEST_ADS=false \
  --export-options-plist=ios/ExportOptions.plist
python3 tool/validate_privacy_manifests.py build/ios/archive/Runner.xcarchive
python3 tool/validate_privacy_manifests.py build/ios/ipa/LastReel.ipa
```

## Privacy manifest validation

The app declares tracking because AdMob can use the IDFA after ATT permission.
Its tracking domain is `googleads.g.doubleclick.net`, Google's ad-request host.
Keep the list aligned with the advertising services actually integrated.

Apple's ITMS-91064 wording mentions domains with tracking disabled, but the
reverse combination is also invalid: tracking enabled with an empty domain
array. Build 10 contained that reverse mismatch in the app's root manifest.
Keep tracking enabled and supply the domain; do not remove truthful tracking
or collected-data disclosures just to pass validation. The preflight above
scans every embedded manifest, including SDK bundles, in the actual IPA.
Do not patch or re-sign the rejected IPA; rebuild it from corrected source.

References:
- https://developer.apple.com/documentation/technotes/tn3181-debugging-invalid-privacy-manifest
- https://developers.google.com/admob/android/network-tracing (Google's documented ad-request host)

## AdMob console (owner)

- **Privacy & messaging → IDFA explainer: unpublish it.** If it is published,
  Google's consent SDK shows its own "Our app wants to stay free for you" popup
  and Apple's tracking alert on the first ad request, skipping LastReel's
  explanation and causing competing permission presentations.
- Keep the GDPR (EEA/UK) message published; it is unrelated to ATT.
- Register the test iPad's IDFA under Settings → Test devices before tapping
  any ad on a release build.

## App Store Connect → App Privacy (owner)

These answers match `ios/Runner/PrivacyInfo.xcprivacy`. Choose **"Yes, we
collect data"**, and **"Yes" to tracking** (AdMob may use the IDFA once ATT
allows it).

| Data type | Linked to user | Used for tracking | Purposes |
| --- | --- | --- | --- |
| Contact info → Name | Yes | No | App functionality |
| Contact info → Email address | Yes | No | App functionality |
| Identifiers → User ID | Yes | No | App functionality |
| User content → Other user content (projects, credits) | Yes | No | App functionality |
| Usage data → Product interaction (Firebase Analytics, Clarity) | No | No | Analytics |
| Identifiers → Device ID (IDFA, analytics instance ID) | No | Yes | Third-party advertising, Analytics |
| Usage data → Advertising data (AdMob) | No | Yes | Third-party advertising |
| Location → Coarse location (AdMob, from IP) | No | Yes | Third-party advertising |

If App Store Connect reports a missing required-reason API after upload, add
it to `PrivacyInfo.xcprivacy` with the reason the email names.

## Device check before submitting

On a real iPad (both orientations) and an iPhone, Free account:

- [ ] Editor: ad card under the block list (landscape) / at the bottom edge
      (portrait); hidden while the keyboard is up.
- [ ] Timing & Look: one ad in the same place on both tabs.
- [ ] Render the roll: ad right under Motion blur.
- [ ] Library and Rendering ads draw the tablet card on iPad.
- [ ] No ad anywhere in Settings.
- [ ] Fresh install: first Home visit shows the neutral explanation; Continue
      opens native ATT after the explanation fully dismisses. AdMob/UMP start
      only after ATT has a decided status.
- [ ] Allow and deny paths retain access and show ads according to ATT and UMP.
- [ ] A legacy pre-prompt flag cannot suppress an undecided ATT request.
- [ ] An interrupted/undecided ATT request can retry after returning to Home.
- [ ] On iPhone and both iPad orientations, capture physical-device screen
      recording from fresh install/reset permissions through native ATT and
      the following app flow. Attach the recording to App Review information
      and explain the first-Home path in the review notes.
- [ ] Firebase advertising storage, user-data sharing and personalization are
      disabled; its independent usage-analytics setting is not ad consent.
- [ ] No "See LastReel Pro", plan card, trial or "Remove ads" anywhere.

## SKAdNetwork

`Info.plist` lists Google's 50 SKAdNetwork IDs, from
https://developers.google.com/admob/ios/3p-skadnetworks (fetched 2026-10-31).
Google adds partners now and then; refresh the list before a release.
