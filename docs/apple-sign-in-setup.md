# LastReel — Sign in with Apple and App Review

## Rejection addressed

The October 21, 2026 review of submission
`920fcb1d-5717-40dc-a356-2f8b11f85a09` identified two independent issues:

- **4.8 Login Services:** Google sign-in was offered without an equivalent private sign-in option.
- **2.1 App Completeness:** the supplied review account could not sign in. Firebase lists that account as **Google only**, so supplying its Google password in the app's email/password form cannot work.

Do not resubmit until both Apple sign-in and reviewer access have been checked in the new build.

## Configuration

| Setting | LastReel value |
| --- | --- |
| Firebase project | `endcrawl-620c2` |
| iOS bundle identifier | `com.lastreel.app` |
| Apple Team ID | `UA47GB93N8` |
| Primary Apple App ID | LastReel |
| Apple Services ID | `com.lastreel.firebaseauth` |
| Apple key | LastReel Firebase Apple Login (`C9B3SLV722`) |
| OAuth domain | `endcrawl-620c2.firebaseapp.com` |
| OAuth return URL | `https://endcrawl-620c2.firebaseapp.com/__/auth/handler` |
| Xcode entitlement | `com.apple.developer.applesignin = [Default]` |
| Release provisioning profile | `LastReel App Store` |

The Apple provider uses a separate LastReel key, not TextCrawl's key. The private
key is backed up outside the checkout at
`~/.config/lastreel/apple/AuthKey_C9B3SLV722.p8` (directory mode 0700, file mode
0600). Never commit this file or include it in app assets, review notes or logs.
The Firebase console holds the server-side OAuth configuration; the app does
not contain the key.

## Setup verified on October 21, 2026

- The LastReel App ID capability, Services ID/callback and Firebase Apple
  provider are enabled. The Apple key is scoped to LastReel.
- `noreply@endcrawl-620c2.firebaseapp.com` is registered as an Apple private
  email relay source; Apple reports a passing SPF check.
- The regenerated App Store profile UUID is
  `438a82cd-12c3-4d75-89e4-37f057ec0ad2`. It is installed in the current
  Xcode UserData profile folder and the legacy MobileDevice profile folder.
  Its embedded Apple entitlement and matching local distribution identity
  were verified. The incompatible old profile is backed up under
  `~/.config/lastreel/apple/retired-profiles/`.
- Xcode resolves Release to `com.lastreel.app`, `LastReel App Store`, and
  `Runner/Runner.entitlements`. Debug and Profile also select the entitlement.
- **Reviewer email/password setup is left to the owner**, as requested.
  It is a separate requirement from enabling Apple authentication.

## Implementation

- `Features.appleSignIn` offers native Apple sign-in on iPhone and iPad,
  including welcome, email sign-in and account settings. Provider buttons
  keep their full titles and equal prominence; narrow layouts stack them. Android and web keep
  their existing sign-in options.
- The existing Firebase Auth repository and controller drive sign-in, linking
  and reauthentication. No extra identity SDK is added. Firebase's native
  Apple implementation generates and hashes the nonce and preserves the name
  returned on first authorization. Requested scopes are name and email.
- A private relay email is accepted as the account identity. It does not force
  the user to disclose a different email or enter the password verification
  flow for a social account.
- Linking Apple to other sign-in methods requires explicit in-app consent.
  Cancellation leaves methods unchanged; the final sign-in method cannot be
  removed.
- Apple disconnection reauthenticates, revokes the fresh Apple authorization,
  then unlinks. Account deletion similarly prepares/revokes authorization
  **before** deleting any projects, profile or Firebase user. A missing code,
  account mismatch, cancellation or revocation failure stops deletion.
- Debug, Profile and Release use `Runner/Runner.entitlements`. Release keeps
  the existing manual App Store signing identity/profile.

## Required reviewer-account step

The account owner must set up a working email/password method themselves:

1. Sign into the existing review account in LastReel using **Google**.
2. Open **Settings → Profile → Email & password → Connect**.
3. Enter and save the desired review password. This links a password to the
   same verified Firebase user and preserves its projects.
4. Sign out and test **Sign in → Email / Password** using the exact credentials
   that will be supplied to App Review. Do not use Continue with Google for
   this verification.
5. In App Store Connect, open the rejected iOS version → App Review Information
   and update the review credentials if they changed. Supply them only in
   that protected form, never in this repository or a public note.

A password reset or Google account password alone does not establish that the
email/password method works. The actual app login must succeed. Do not disable
email verification globally or bypass authentication for reviewers.

## Build and verify

The owner will create/upload the final build. The rejected App Store version
is **1.0**, while the rejected binary reports **0.0.1 (5)**. Match the App Store
version and use a new unused build number (6 below, if it has not been used):

```sh
cd app
flutter pub get
flutter build ipa --build-name=1.0 --build-number=6 --export-options-plist=ios/ExportOptions.plist
```

The provisioning profile must have been regenerated after enabling the Apple
capability and installed locally. Reopen Xcode if it cached the old profile.
The new profile must include `com.apple.developer.applesignin = [Default]`
and application identifier `UA47GB93N8.com.lastreel.app`.

On an iPhone and iPad signed into an Apple Account with two-factor
authentication, verify:

- Continue with Apple appears alongside Google on welcome and sign-in.
- First authorization works with **Hide My Email**; the account reaches Projects.
- Sign out, sign back in, cancel the native sheet and retry.
- Link another method only after the consent sheet; cancellation changes nothing.
- On a disposable test account, verify deletion revokes Apple access and removes
  the user and its data. Do not delete a real account to test this.
- The review account can sign in using email/password and reach the full app.

The unit/widget checks do not authenticate a real Apple Account or certify an
archive; the owner must complete these checks in the newly signed build.

## Validation

- 59 authentication/account tests passed; 3 pre-existing tests remain skipped.
- Welcome and email sign-in checked at phone portrait/landscape and iPad
  portrait/landscape sizes, including complete Apple/Google button labels.
- `flutter analyze`: no issues found.
- `plutil` validates the Xcode project and entitlement file.
- Xcode Release build settings resolve successfully with the Apple entitlement;
  Debug/Profile/Release configuration references were also checked directly.
- The installed distribution profile includes Apple sign-in, uses the correct
  bundle/team identifiers, and matches a signing identity in the local keychain.
- A real Apple Account sign-in/deletion smoke test and final archive/upload are
  pending the owner's new build. Reviewer email/password setup is owned by the
  user and was not completed as part of this setup.

## References

- [Firebase Flutter federated authentication](https://firebase.google.com/docs/auth/flutter/federated-auth#apple)
- [Firebase Apple authentication and private email relay](https://firebase.google.com/docs/auth/ios/apple)
- [Apple review guideline 4.8](https://developer.apple.com/app-store/review/guidelines/#login-services)
