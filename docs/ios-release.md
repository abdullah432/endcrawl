# iOS release checklist

For the free iOS launch (`IOS_FREE_LAUNCH=true`, the default): no
subscriptions, a paywall or a Subscription page on iPhone and iPad; Free shows
ads, with the App Tracking Transparency pre-prompt three days after install.

## Version

`pubspec.yaml` is `1.0.0+17`. App Store Connect already has 1.0.0 (build 6),
so this uploads as 1.0.0 build 17; Android gets versionCode 17. Every later
upload needs a higher build number.

```sh
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

## AdMob console (owner)

- **Privacy & messaging → IDFA explainer: unpublish it.** If it is published,
  Google's consent SDK shows its own "Our app wants to stay free for you" popup
  and Apple's tracking alert on the first ad request, skipping LastReel's
  pre-prompt and its three-day wait.
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
- [ ] Tracking: no popup on days 0–2. On a device whose first launch was
      three or more days ago (or with the date moved forward), the LastReel
      pre-prompt shows once, Continue opens Apple's alert, and
      Privacy & data then shows "Ad personalisation · On/Off".
- [ ] No "See LastReel Pro", plan card, trial or "Remove ads" anywhere.

## Still to do

- **SKAdNetwork IDs**: `Info.plist` lists only Google's own
  (`cstr6suwn9.skadnetwork`). Add Google's full partner list from
  https://developers.google.com/admob/ios/3p-skadnetworks to raise ad revenue
  from users who allow tracking. Not required for review.
