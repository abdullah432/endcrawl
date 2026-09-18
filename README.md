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
- [`design/`](design/) — the original Claude Design handoff bundle this app was
  built from: the design prompt, chat transcript, and the interactive HTML/JS
  prototype (`design/project/EndCrawl.dc.html`). Kept for reference; not part
  of the shipped app.

## Status

UI/UX is implemented with full fidelity to the prototype: format & fps setup,
the block editor (title, two-column cast, department, hold cards, logos,
soundtrack, special thanks, spacers), the roll engine (frame-locked scroll,
judder/readability checks, duration & speed lock), the real-time monitor
(2D/3D look, backgrounds, safe guides, rotate-to-preview), paste-and-split
bulk entry, and the export flow. Export itself is simulated — there is no
video encoder behind it in this build.

Projects live in Firestore under `users/{uid}/projects/{projectId}`, with
offline persistence on, behind a `ProjectRepository` seam: a versioned
document schema, debounced autosave, a project library, and real crash
recovery. Accounts are Firebase Authentication — email/password and Google
Sign-in — behind a one-screen welcome with a live credit roll for a backdrop.
See [`app/README.md`](app/README.md#data-layer) for the schema and the
layering, and [Onboarding and accounts](app/README.md#onboarding-and-accounts)
for the sign-in flow.

## Firebase setup

The app code is wired up, but the generated Firebase config is
machine-specific and not in the repo. One person has to run the steps in
[`app/README.md`](app/README.md#firebase-setup) once against the
`endcrawl-620c2` project — `flutterfire configure`, enabling the two sign-in
providers, and `firebase deploy --only firestore` — before the app will
build.

**Next:** a real export pipeline. Guest mode (Firebase Anonymous Auth,
upgradable in place) is a deliberate deferral, not an oversight.
