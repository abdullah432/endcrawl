# Account profile repair and project counts

The new synchronization is disabled by default. No production deployment or
rollout is performed by the test or preparation scripts.

## Behavior and compatibility

`users/{uid}` keeps schema version 1 and the existing `marketingOptIn`,
`preferences`, and `updatedAt` fields. Optional server-maintained `name`, `email`,
and `projectCount` fields are populated from Firebase Authentication and the
actual project subcollection. Absent provider identity preserves a saved value;
when neither exists, the identity field is null. Apple relay email is retained.

The authenticated `ensureUserProfile` callable ignores identity/UID supplied by
the caller. A Firestore transaction reads the current profile, deletion guard,
and projected project documents, then merges only changed metadata and missing
defaults. Existing settings and project contents are never rewritten by repair.

Project creation/deletion triggers reconcile the current count rather than
applying increments, making retries and delayed events safe. Editing a project
does not change its count. The count is eventually consistent in Firestore;
existing live project lists and entitlement providers continue to control the
app. There are no new project restrictions, including for the iOS Free launch.

Signed-in desktop browsers open the project library immediately. Without a
verified Pro entitlement, the existing preview guards allow opening/playback
but block edits, creation, management and export. Pending or failed entitlement
checks do not delay entry. Locked actions explain the Pro requirement and link
to mobile subscription instructions; that page is opened only on request.

Updated clients merge settings without serializing server metadata. Legacy
clients can still replace their settings document; the legacy repair trigger
restores missing metadata. Rules permit unchanged metadata or legacy omission,
but reject client-assigned identity/count and entitlement fields.

Root session synchronization runs after sign-in, on restored sessions and
identity changes, and on app resume. Requests are serialized, account-scoped,
and retried at 1, 2, 4, 8, 16, then 30-second intervals after transient errors.
Failed repair never holds the auth gate or library open. In pilot builds, signup
persists both marketing choices; other accounts retain the old signup behavior.

Deletion drains local repair and uses `setProfileDeletionState` to suspend
backend reconciliation in `profileSyncState/{uid}`, including on other devices.
The guard expires after ten minutes if deletion was interrupted. Failed deletion
attempts release it immediately when possible. Trigger repair only updates
existing parent documents, never recreates deleted parents, and verifies that
the Auth account still exists. Owner access to guard documents is denied.

## Local validation

Install the existing backend dependencies with `npm --prefix functions ci`.
Use Node 22, Java 21+, and Firebase CLI. From the repository root:

```sh
npm --prefix functions run test:profiles
cd app
flutter analyze --no-pub
flutter test --no-pub
```

The runner starts Auth, Firestore, and Functions emulators with
`firebase.profiles-test.json` and `demo-lastreel-profiles`. It creates temporary
ignored local function settings, uses dummy billing secrets, and removes those
settings on exit. Existing local settings are never overwritten. The integration
suite fails if any required emulator host or the dedicated demo project is
missing. The suite invokes the real callable and event handlers, exercises the
rules, and includes existing billing unit/emulator tests.

The pilot fixture uses `abdullah234ktk@gmail.com` with a local-only password.
It is not a login to the real Google account. Google/Apple provider responses
are mocked locally; interactive provider authentication remains a device check.
A second account proves pilot callables and triggers make no writes outside the
configured UID.

For a rehearsal with the real pilot account's read-only snapshot:

```sh
npm --prefix functions run prepare:profile-pilot
PROFILE_TEST_SNAPSHOT=/absolute/path/to/snapshot.json npm --prefix functions run test:profiles
```

Preparation is pinned to project `endcrawl-620c2` and the designated email. It
resolves the Auth UID and reads only that account's profile/projects. It reuses
the Firebase CLI login or Application Default Credentials. Private snapshots and
unapplied settings are created with restricted file permissions under ignored
`output/profile-pilot/<timestamp>/`. Tokens and password hashes are not exported.
Errors are sanitized so credential headers cannot appear in terminal output.

The optional snapshot test imports those project documents into the demo
emulator under the same UID, repairs its local missing parent, and compares every
project before/after. It never writes back to the source project. Capture a fresh
snapshot if the real pilot account changes.

## Single-account deployment

On 23 October 2026, the user authorized the pilot deployment. The compatible
rules, four profile functions, and a web build pinned to the resolved pilot UID
were deployed. Global rollout remains disabled. See
[the validation record](account-profile-validation.md) for verified behavior and
the remaining interactive app check.

There are independent backend and client controls:

| Control | Default | Pilot value |
| --- | --- | --- |
| Backend `PROFILE_ROLLOUT_MODE` | `off` | `pilot` |
| Backend `PROFILE_PILOT_UID` | empty | UID resolved by preparation |
| App `PROFILE_SYNC_ENABLED` | `false` | `true` |
| App `PROFILE_SYNC_PILOT_UID` | empty | same resolved UID |
| Web `FIREBASE_AUTH_DOMAIN` | `endcrawl-620c2.firebaseapp.com` | `endcrawl-620c2.web.app` |

The pilot web build uses a full-page Google redirect. Its auth domain must match
the hosting domain to avoid cross-origin storage restrictions. The existing
Google OAuth client retains its original origins/callback and also authorizes
`https://endcrawl-620c2.web.app` and
`https://endcrawl-620c2.web.app/__/auth/handler`. Keep the matching callback
configured when deploying to another domain. Native provider flows are unchanged.
See Firebase's [redirect guidance](https://firebase.google.com/docs/auth/web/redirect-best-practices).

After local validation and a separate deployment decision:

1. Capture a fresh snapshot. Copy only the two generated `pilot.env` entries
   into `functions/.env.endcrawl-620c2`, preserving any existing unrelated values.
2. Prepare a focused package containing the exact tested profile handlers. This
   avoids resolving or deploying unrelated billing functions/secrets. Packaging
   refuses global mode or a UID that differs from the designated account snapshot.

   ```sh
   npm --prefix functions run prepare:profile-deployment
   ```

   Deploy the compatible rules and only the four new functions:

   ```sh
   firebase deploy --config output/profile-pilot/deployment/firebase.json --project endcrawl-620c2 --only firestore:rules,functions:ensureUserProfile,functions:setProfileDeletionState,functions:reconcileProjectCount,functions:repairLegacyUserProfile --non-interactive --force
   ```

3. Run a pilot app build using the generated defines file:

   ```sh
   flutter run --dart-define-from-file=/absolute/path/to/app-pilot-defines.json
   ```

4. Sign in as the designated account. Verify its identity/count, project opening,
   editing/export, preferences, create/duplicate/delete/undo, and app reopening.
   Existing Free/Pro access must match the previous build.
5. Capture another read-only snapshot and compare unchanged project contents and
   preferences, accounting only for deliberate pilot edits. Check function error
   logs without including personal content in the validation report.

The backend exercise can also be repeated with
`npm --prefix functions run verify:profile-pilot`. It first checks that all four
deployed functions are ACTIVE and restricted to the freshly resolved pilot UID.
It uses administrator credentials to exercise legacy profile repair, a temporary
project create/edit/delete, count changes, and preference/consent preservation.
It does not sign in as another user or mint Firebase sessions. This backend check
is separate from interactive sign-in, client-rule checks, and on-device use.
Private before/after snapshots and results remain under ignored
`output/profile-pilot/live-<timestamp>/`.

Disable backend `PROFILE_ROLLOUT_MODE` and redeploy the new functions to stop
synchronization if the pilot fails. Existing data and access rules remain intact.
Do not roll back to old Firestore rules after metadata exists: the old rules do
not accept metadata-preserving settings writes.

## Broader rollout

Only after the pilot passes and a separate rollout decision, set the backend mode
to `all`, leave the pilot UID empty in the enabled release build, and deploy/release
those changes. Existing accounts backfill on their next authenticated session.
There is no bulk production migration and no automatic promotion after tests.

## Android and iOS release requirements

Both mobile apps need a new store release for session-based profile repair,
merged settings saves, and deletion coordination. Existing installations do not
contain the new session-sync code. Backend triggers alone cannot repair missing
parent documents when those users sign in; those triggers intentionally skip
missing parents to avoid recreating deleted accounts.

After the remaining device/Pro pilot checks pass and the backend is enabled for
all accounts, build each platform with `PROFILE_SYNC_ENABLED=true` and leave
`PROFILE_SYNC_PILOT_UID` unset. The default is still disabled. From `app/`:

```sh
flutter build appbundle --release --no-pub --dart-define=PROFILE_SYNC_ENABLED=true
flutter build ipa --release --no-pub --dart-define=PROFILE_SYNC_ENABLED=true
```

Retain all existing platform-specific release defines and signing settings.
Use new store-accepted version/build numbers for each upload; the unrelated
current version edits in `pubspec.yaml` have not been changed by this work.
These commands do not upload or release the apps. Web UI updates deploy through
Hosting and do not require a mobile store release.
