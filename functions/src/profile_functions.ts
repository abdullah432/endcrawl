import { getAuth } from 'firebase-admin/auth';
import { defineString } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { db } from './firebase.js';
import { hasProfileMetadata, profileEnabled, reconcileProfile, setProfileSuspended } from './profiles.js';

const profileMode = defineString('PROFILE_ROLLOUT_MODE', { default: 'off' });
const profilePilotUid = defineString('PROFILE_PILOT_UID', { default: '' });
const profilesEnabled = (uid: string) => profileEnabled(uid, {
  mode: profileMode.value(), pilotUid: profilePilotUid.value(),
});

export const ensureUserProfile = onCall({ region: 'us-central1' }, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in to sync your profile.');
  const uid = request.auth.uid;
  if (!profilesEnabled(uid)) return { status: 'disabled' };
  try {
    return { status: await reconcileProfile(uid, db, account => getAuth().getUser(account), true) };
  } catch (error: any) {
    if (error.code === 'auth/user-not-found') throw new HttpsError('unauthenticated', 'Account no longer exists.');
    throw new HttpsError('unavailable', 'Profile sync will retry later.');
  }
});

export const setProfileDeletionState = onCall({ region: 'us-central1' }, async request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in to delete your profile.');
  if (!profilesEnabled(request.auth.uid)) return { status: 'disabled' };
  if (typeof request.data?.suspended !== 'boolean') throw new HttpsError('invalid-argument', 'Missing deletion state.');
  await setProfileSuspended(request.auth.uid, db, request.data.suspended);
  return { status: 'synced' };
});

async function repairExistingProfile(uid: string) {
  if (!profilesEnabled(uid)) return;
  try { await reconcileProfile(uid, db, account => getAuth().getUser(account)); }
  catch (error: any) {
    if (error.code !== 'auth/user-not-found') throw new Error('Account profile repair failed; retrying.');
  }
}

export const reconcileProjectCount = onDocumentWritten({ region: 'us-central1',
  document: 'users/{uid}/projects/{projectId}', retry: true }, async event => {
  if (!event.data || event.data.before.exists === event.data.after.exists) return;
  await repairExistingProfile(event.params.uid);
});

export const repairLegacyUserProfile = onDocumentWritten({ region: 'us-central1',
  document: 'users/{uid}', retry: true }, async event => {
  const after = event.data?.after;
  if (!after?.exists || hasProfileMetadata(after.data()!)) return;
  await repairExistingProfile(event.params.uid);
});

