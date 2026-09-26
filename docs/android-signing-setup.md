# Android Signing & Release Setup

This document describes how Android release signing is configured for LastReel (`com.lastreel.app`).

---

## Overview

Release builds (`.aab` / `.apk`) require an upload keystore to sign the application before submitting to the Google Play Store.

Signing files and credentials are kept strictly out of version control and are stored in the local `credentials/` folder at the repository root (or in `app/android/`), which is ignored by `.gitignore`.

---

## Credentials Directory (`credentials/`)

The repository root includes a gitignored `credentials/` folder containing:
* `upload-keystore.jks`: The upload keystore in PKCS12 format.
* `key.properties`: Configuration file defining key passwords, alias, and path to the keystore.
* `README.md`: Secure offline documentation with key details and certificate fingerprints.

### `key.properties` Template

```properties
storePassword=<STORE_PASSWORD>
keyPassword=<KEY_PASSWORD>
keyAlias=upload
storeFile=upload-keystore.jks
```

---

## Build Configuration

The Android application build script in [`app/android/app/build.gradle.kts`](file:///Users/abdullahkhan/Documents/Development/COOKOO/Projects/endcrawl/app/android/app/build.gradle.kts) automatically detects `key.properties` from either:
1. `app/android/key.properties`
2. `credentials/key.properties`

If present and valid, it signs the `release` build type using this upload keystore. If absent, it gracefully falls back to debug signing for local test builds.

---

## Generating a Release Bundle

To create a signed Android App Bundle (`.aab`) for Google Play Store upload:

```bash
cd app
flutter build appbundle --release
```

The resulting file will be output to:
```
app/build/app/outputs/bundle/release/app-release.aab
```

---

## Google Play Console & Firebase

1. **Upload Key vs App Signing Key:** When you upload the `.aab` to Google Play Console for the first time, Google Play App Signing will register your upload key and create an App Signing certificate.
2. **SHA Fingerprints:** Ensure the SHA-1 and SHA-256 fingerprints from both your upload keystore and Google Play Console's App Signing key are registered in Firebase Console (**Project Settings > Your Apps > `lastreel (android)`**) so Google Sign-In and Firebase Auth work properly.
