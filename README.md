# EndCrawl

A dedicated end-credits roll editor for phones — an indie filmmaker, YouTuber,
or film student produces a broadcast-clean rolling credit sequence on their
phone in under 60 seconds. No AI, no keyframing: the runtime is the input,
the motion is derived.

This repo contains the real Flutter implementation, built from the interactive
prototype exported by Claude Design (see [`design/`](design/)).

## Contents

- [`app/`](app/) — the Flutter app (iOS & Android). See [`app/README.md`](app/README.md)
  for architecture, setup, and how to run it.
- [`firestore.rules`](firestore.rules) — Firestore Security Rules for the
  `users/{uid}/projects/{projectId}` model.
- [`firestore.indexes.json`](firestore.indexes.json) / [`firebase.json`](firebase.json) /
  [`.firebaserc`](.firebaserc) — Firebase CLI project config, so rules deploy
  with a single `firebase deploy`.
- [`design/app-light/`](design/app-light/) — the current design the app is
  built to (`EndCrawl App Light.dc.html`).
- [`design/`](design/) — the original handoff bundle (prompt, transcript and
  first prototype), kept for reference; not part of the shipped app.

## Status

The app follows the v2 design in [`design/app-light/`](design/app-light/)
(light, "Aurora Noir"): onboarding with Google and email (Apple is built but switched off); a library
of numbered reels with a three-project free plan; templates with editable
contents; the editor with its readability warnings, multi-select and swipe
actions; 27 block types with paste-and-split and a fast cast editor; timing,
look and background; export; and settings with account management and
account deletion.

Projects live in Firestore under `users/{uid}/projects/{projectId}` (with a
`users/{uid}` profile for preferences), offline-first, with autosave and
crash recovery. Export renders on the device through the platform's own
encoders (H.264, HEVC, ProRes where the hardware has it, and PNG
sequences); purchases and ads sit behind seams awaiting a store and an ad
SDK. See [`app/README.md`](app/README.md) for the architecture and what is
a placeholder.

## Firebase setup

The app code is wired up, but the generated Firebase config is
machine-specific and not in the repo. One person has to run the steps in
[`app/README.md`](app/README.md#firebase-setup) once against the
`endcrawl-620c2` project — `flutterfire configure`, enabling the Google and email
providers, and `firebase deploy --only firestore` (redeploy after
this update: the rules changed) — before the app will build.

**Next:** a store for Pro and an ad SDK. Guest mode (Firebase Anonymous Auth,
upgradable in place) is a deliberate deferral, not an oversight.
