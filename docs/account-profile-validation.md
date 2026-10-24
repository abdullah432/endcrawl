# Account profile validation — 23 October 2026

Status: implemented, locally verified, and deployed as a pilot after explicit
user authorization. Backend mode is `pilot`; the app build is pinned to the same
UID. Global rollout remains disabled.

| Check | Result |
| --- | --- |
| Flutter static analysis (`flutter analyze --no-pub`) | Pass; no issues |
| Full Flutter suite (`flutter test --no-pub`) | 615 passed, 5 skipped |
| Node 22 backend unit and Auth/Firestore/Functions emulator suite | 22 passed, 0 skipped |
| Integration test safety guard | Rejects production project IDs and missing emulator configuration |
| Whitespace validation (`git diff --check`) | Pass |

## Designated account rehearsal

A read-only lookup of `abdullah234ktk@gmail.com` in `endcrawl-620c2` confirmed
four stored projects and a missing parent user document. The real UID was resolved
for the pilot configuration. A private snapshot and unapplied backend/app pilot
settings were saved under ignored
`output/profile-pilot/2026-10-23T14-10-48.991Z/` with restricted permissions.

The snapshot was imported into `demo-lastreel-profiles` locally under the same
UID. Calling the real emulated reconciliation function created the local parent
with the Auth name/email and `projectCount: 4`. Every imported project matched
its original contents after repair. No production account or project was changed.

## Verified scenarios

- Pilot UID gating for callables and triggers; no profile/counter writes for a
  second account. Invalid/off rollout settings fail closed.
- Missing and partial profiles, repeated reconciliation, renamed identities,
  custom preferences, and existing marketing consent.
- Email, Google, Apple relay email, absent provider identity, restored sessions,
  and explicit true/false marketing choices in pilot signups.
- Counts of zero, one, two, and more projects; creation, duplication, editing,
  deletion, undo, bulk deletion, concurrent changes, repeated reconciliation,
  and project documents an older client cannot deserialize.
- Legacy settings replacement followed by metadata repair; new merge saves
  retain metadata. Forged metadata, entitlement fields, cross-account reads,
  unauthenticated calls, and client access to deletion guards are denied.
- Background retry/backoff, account switching, sign-out, and continued library
  access while synchronization is pending or fails.
- Deletion drains pending work, suspends backend repair, resumes after failure,
  and prevents late triggers from recreating a deleted parent. Interrupted guard
  expiration and the verification screen's alternate-email flow are covered.
- Existing billing reconciliation, Free/Pro access, iOS Free launch behavior,
  library, editor, and export regression tests remain passing.

## Live pilot verification

The compatible rules and four profile functions were deployed to `endcrawl-620c2`.
The main web app was deployed with `PROFILE_SYNC_ENABLED=true` and the designated
UID in `PROFILE_SYNC_PILOT_UID`. All four deployed function configurations were
checked as ACTIVE with `PROFILE_ROLLOUT_MODE=pilot` and that same UID.

The backend exercise on the real account passed:

- The deployed profile worker populated the Firebase Auth name/email and count 4.
- Creating a temporary project changed the count to 5; editing kept 5; deleting
  the test project returned the count to 4.
- Preference merge and legacy full replacement both preserved original settings
  and marketing consent, while the deployed worker restored server metadata.
- All four original Firestore project snapshots, including update timestamps,
  matched before/after. No original project was edited or removed.

This exercise used administrator credentials. It verifies the live workers and
data preservation, not interactive Firebase client authentication. Its private
artifacts are in `output/profile-pilot/live-2026-10-23T15-27-11.513Z/`.

The initial function deployment encountered first-use Google service enablement
and Eventarc permission propagation. Retrying after provisioning completed
succeeded. A focused deployment entry point avoids inspecting unrelated billing
secrets; no billing functions were deployed.

## Interactive web verification

The designated Google account is signed in on the deployed pilot. Cloud Function
logs show authenticated (`auth: VALID`) `ensureUserProfile` requests. A fresh
read-only snapshot at `output/profile-pilot/2026-10-23T16-10-09.156Z/` confirms
the Auth name/email and `projectCount: 4`; all four original projects and their
Firestore timestamps match the predeployment snapshot exactly.

The desktop library displays the account name/email and four projects. An
existing project opens with its blocks and plays successfully in preview. A page
reload restores the same authenticated account without another sign-in.

Google popup attempts initially ended with `popup-closed-by-user`. The pilot now
uses Google redirect sign-in and a same-origin `web.app` auth domain, with that
first-party callback added to the existing OAuth client. Existing callback URIs
were retained. This follows Firebase's [redirect configuration guidance](https://firebase.google.com/docs/auth/web/redirect-best-practices).
Pilot-only startup diagnostics contain stage names and error codes, never
credentials or provider response objects. Regression tests cover redirect
selection, restored sessions, and handled errors.

A separate existing web access bug left failed subscription checks on a loading
screen. It now offers the existing retry/preview page without granting Pro.
The regression test failed before the fix and passes afterward. Chrome's device
emulation was also enabled; disabling it restored the desktop layout.

## Desktop preview follow-up

At the user's request, signed-in desktop browsers now enter the library directly,
without the subscription landing page or an entitlement-loading gate. The
existing workspace guards keep Free, loading, and failed checks in preview;
verified Pro unlocks editing. Locked actions explain that web/desktop editing
requires Pro through the mobile app with the same account. Subscription
instructions remain available on request, and their return button goes back to
the workspace. Phone browser handoff and native app access rules are preserved.

The focused access/entitlement/phone-handoff suite passes all 15 tests, including
pending and failed initial entitlement checks, blocked creation/export, the
mobile subscription handoff, verified Pro unlocking, and entitlement loss.
The full Flutter suite passes 615 tests with five existing skips; static analysis
reports no issues.

The follow-up web build was deployed to the existing app hosting target. Reloading
the designated account opens its four-project library directly in preview,
without the subscription page. Clicking New project opens the Pro explanation
with mobile/same-account instructions and leaves the project count at four.
Choosing Keep previewing returns to the library. Screenshots are saved privately
under `output/profile-pilot/desktop-direct-preview.png` and
`output/profile-pilot/desktop-pro-lock.png`. No backend functions or rollout
configuration were changed for this follow-up; profile sync remains pilot-only.

## Remaining release checks

The account currently enters Free web preview. On 24 October the billing refresh,
webhook and worker were deployed separately with their own account-only guard.
Live checks now match RevenueCat: this Firebase account has no subscription or
Pro entitlement. Project opening/playback is verified, but live web editing/export
and real Pro entitlement verification await purchase restoration on this account.
Do not grant a test entitlement to bypass this
check. Apple authentication and native-device use also remain unperformed; local
provider responses are mocked. Existing native access/editor/export tests pass.
Broader rollout remains disabled pending those checks and a separate decision.

Before that billing follow-up, a read-only inventory confirmed four ACTIVE profile
handlers in pilot mode and no billing-refresh function. The missing function is
now resolved. Live billing verification confirms that all seven profile/billing
handlers remain ACTIVE with their respective pilot guards. Purchase restoration,
Pro editing/export and the device checks above remain open, so the user's
condition for broader rollout has not been met. No global rollout was enabled.
Both mobile platforms require updated releases to deliver the session-sync code;
the release flag requirements are documented in `account-profiles.md`.

Private billing verification artifacts are in
`output/billing-pilot/live-2026-10-23T20-19-44.213Z/`. The signed-in browser's
refresh requests pass Firebase authentication and return the same Free result as
RevenueCat. RevenueCat's own integration test returned HTTP 200. Original project
snapshots, preferences and consent match before/after. Temporary local copies of
the webhook credential were removed after configuration; repeat verification
loads it directly into memory from Firebase Secret Manager.

The pre-existing edits in `app/pubspec.yaml` and `app/pubspec.lock` were preserved;
Flutter checks used `--no-pub`.
