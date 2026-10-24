import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { setTimeout as delay } from 'node:timers/promises';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp, FieldValue, GeoPoint } from 'firebase-admin/firestore';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore';
import { reconcileProfile, defaultPreferences, setProfileSuspended } from '../lib/profiles.js';

// This suite never skips silently and cannot fall back to production services.
const projectId = process.env.GCLOUD_PROJECT;
if (!projectId?.startsWith('demo-') || projectId !== 'demo-lastreel-profiles') {
  throw new Error('Profile integration tests require the dedicated demo-lastreel-profiles project.');
}
for (const key of ['FIREBASE_AUTH_EMULATOR_HOST', 'FIRESTORE_EMULATOR_HOST', 'FUNCTIONS_EMULATOR_HOST']) {
  if (!/^127\.0\.0\.1:\d+$/.test(process.env[key] ?? '')) throw new Error(`Missing local ${key}; refusing to run.`);
}
const app = initializeApp({ projectId }, 'profile-tests');
const auth = getAuth(app);
const db = getFirestore(app);
const uid = process.env.PROFILE_TEST_UID || 'local-profile-pilot';
const email = 'abdullah234ktk@gmail.com';
const password = 'Emulator-only-123';
const profile = db.doc(`users/${uid}`);
const projects = profile.collection('projects');
const identity = account => auth.getUser(account);

async function signIn(address) {
  const response = await fetch(`http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-key`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: address, password, returnSecureToken: true }),
  });
  const data = await response.json();
  assert.equal(response.ok, true, JSON.stringify(data));
  return data.idToken;
}
async function callable(name, token, data = {}) {
  const response = await fetch(`http://${process.env.FUNCTIONS_EMULATOR_HOST}/${projectId}/us-central1/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ data }),
  });
  return { code: response.status, ...(await response.json()) };
}
async function eventually(check, label) {
  const deadline = Date.now() + 20_000;
  let error;
  do {
    try { await check(); return; } catch (failure) { error = failure; }
    await delay(100);
  } while (Date.now() < deadline);
  throw new Error(`${label}: ${error}`);
}
async function expectCount(count) {
  await eventually(async () => assert.equal((await profile.get()).get('projectCount'), count), `count ${count}`);
}
function project(id) {
  return { schemaVersion: 2, id, ownerId: uid, title: `Film ${id}`, settings: {}, blocks: [],
    createdAt: Timestamp.fromMillis(1000), updatedAt: Timestamp.fromMillis(1000) };
}
const writableProfile = (extra = {}) => ({ schemaVersion: 1, marketingOptIn: false,
  preferences: defaultPreferences, updatedAt: serverTimestamp(), ...extra });

function decodeFields(fields) {
  return Object.fromEntries(Object.entries(fields ?? {}).map(([key, value]) => [key, decodeValue(value)]));
}
function decodeValue(value) {
  if ('nullValue' in value) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) {
    const number = Number(value.integerValue);
    if (!Number.isSafeInteger(number)) throw new Error('Snapshot integer cannot be preserved exactly.');
    return number;
  }
  if ('doubleValue' in value) return Number(value.doubleValue);
  if ('timestampValue' in value) {
    const fraction = /\.(\d+)Z$/.exec(value.timestampValue)?.[1] ?? '';
    return new Timestamp(Math.floor(Date.parse(value.timestampValue) / 1000), Number(fraction.padEnd(9, '0')));
  }
  if ('mapValue' in value) return decodeFields(value.mapValue.fields);
  if ('arrayValue' in value) return (value.arrayValue.values ?? []).map(decodeValue);
  if ('bytesValue' in value) return Buffer.from(value.bytesValue, 'base64');
  if ('geoPointValue' in value) return new GeoPoint(value.geoPointValue.latitude, value.geoPointValue.longitude);
  throw new Error('Snapshot contains an unsupported field type; refusing a lossy rehearsal.');
}

test('local pilot: authenticated profile repair, live triggers, compatibility, and isolation', async t => {
  let env;
  try {
    await auth.createUser({ uid, email, password, displayName: 'Abdullah Local Fixture', emailVerified: true });
    await auth.createUser({ uid: 'other-account', email: 'other@example.test', password, displayName: 'Other' });
    const token = await signIn(email);
    const otherToken = await signIn('other@example.test');
    if (process.env.PROFILE_TEST_SNAPSHOT) {
      await t.test('real pilot snapshot rehearsal repairs its missing parent and preserves every project', async () => {
        const snapshot = JSON.parse(await readFile(process.env.PROFILE_TEST_SNAPSHOT, 'utf8'));
        assert.equal(snapshot.identity.uid, uid);
        assert.equal(snapshot.identity.email, email);
        assert.equal(snapshot.profile, null);
        await auth.updateUser(uid, { displayName: snapshot.identity.name });
        const originals = new Map();
        for (const item of snapshot.projects) {
          const id = item.name.split('/').at(-1);
          const data = decodeFields(item.fields);
          originals.set(id, data);
          await projects.doc(id).set(data);
        }
        const response = await callable('ensureUserProfile', token);
        assert.equal(response.result.status, 'synced');
        const repaired = (await profile.get()).data();
        assert.equal(repaired.name, snapshot.identity.name);
        assert.equal(repaired.email, email);
        assert.equal(repaired.projectCount, snapshot.projects.length);
        for (const [id, data] of originals) {
          assert.deepEqual((await projects.doc(id).get()).data(), data);
        }
        await setProfileSuspended(uid, db, true);
        const cleanup = db.batch();
        for (const id of originals.keys()) cleanup.delete(projects.doc(id));
        cleanup.delete(profile);
        await cleanup.commit();
        await auth.updateUser(uid, { displayName: 'Abdullah Local Fixture' });
        await setProfileSuspended(uid, db, false);
      });
    }
    const first = project('existing-project-001');
    const second = project('existing-project-002');
    await projects.doc(first.id).set(first);
    await projects.doc(second.id).set(second);

    await t.test('repairs a missing parent through the real callable without changing existing projects', async () => {
      assert.equal((await profile.get()).exists, false);
      const response = await callable('ensureUserProfile', token, { uid: 'other-account', name: 'FORGED', email: 'forged@example.test' });
      assert.equal(response.result.status, 'synced');
      const data = (await profile.get()).data();
      assert.equal(data.name, 'Abdullah Local Fixture');
      assert.equal(data.email, email);
      assert.equal(data.projectCount, 2);
      assert.equal(data.marketingOptIn, false);
      assert.deepEqual(data.preferences, defaultPreferences);
      assert.deepEqual((await projects.doc(first.id).get()).data(), first);
      assert.deepEqual((await projects.doc(second.id).get()).data(), second);
    });

    await t.test('pilot gate makes no writes for a second account, including trigger events', async () => {
      assert.equal((await callable('ensureUserProfile', otherToken)).result.status, 'disabled');
      const other = db.doc('users/other-account');
      await other.collection('projects').doc('one').set({ untouched: true });
      await delay(500);
      assert.equal((await other.get()).exists, false);
      await other.set({ schemaVersion: 1, marketingOptIn: true, preferences: { usageAnalytics: false }, updatedAt: Timestamp.now() });
      const original = (await other.get()).data();
      await other.collection('projects').doc('two').set({ untouched: true });
      await other.collection('projects').doc('one').delete();
      await delay(500);
      assert.deepEqual((await other.get()).data(), original);
      assert.equal((await callable('setProfileDeletionState', otherToken, { suspended: true })).result.status, 'disabled');
      assert.equal((await db.doc('profileSyncState/other-account').get()).exists, false);
    });

    await t.test('preserves settings and consent while updating names and retrying sign-in', async () => {
      const preferences = { ...defaultPreferences, defaultFps: 30, usageAnalytics: false, personalisedAds: true };
      await profile.update({ preferences, marketingOptIn: true });
      await auth.updateUser(uid, { displayName: 'Renamed Account' });
      await Promise.all([callable('ensureUserProfile', token), callable('ensureUserProfile', token)]);
      const data = (await profile.get()).data();
      assert.equal(data.name, 'Renamed Account');
      assert.equal(data.marketingOptIn, true);
      assert.deepEqual(data.preferences, preferences);
    });

    await t.test('partial legacy profiles receive only missing defaults', async () => {
      await setProfileSuspended(uid, db, true);
      await profile.set({ marketingOptIn: true, preferences: { haptics: false }, updatedAt: FieldValue.serverTimestamp() });
      await setProfileSuspended(uid, db, false);
      assert.equal((await callable('ensureUserProfile', token)).result.status, 'synced');
      const data = (await profile.get()).data();
      assert.equal(data.schemaVersion, 1);
      assert.equal(data.marketingOptIn, true);
      assert.deepEqual(data.preferences, { haptics: false });
      assert.equal(data.projectCount, 2);
    });

    await t.test('create, duplicate, edit, delete, and undo update current counts', async () => {
      const third = project('created-project-003');
      const fourth = project('duplicate-project-004');
      await projects.doc(third.id).set(third); await expectCount(3);
      await projects.doc(fourth.id).set(fourth); await expectCount(4);
      await projects.doc(third.id).update({ title: 'Edited title' }); await expectCount(4);
      await projects.doc(fourth.id).delete(); await expectCount(3);
      await projects.doc(fourth.id).set(fourth); await expectCount(4);
    });

    await t.test('concurrent changes and repeated reconciliations cannot double count', async () => {
      const batch = db.batch();
      for (let i = 0; i < 5; i++) batch.set(projects.doc(`concurrent-${i}`), project(`concurrent-${i}`));
      await batch.commit();
      await Promise.all(Array.from({ length: 5 }, () => reconcileProfile(uid, db, identity)));
      await expectCount(9);
      // Delayed events reconcile current state rather than their old snapshots.
      await projects.doc('concurrent-0').delete();
      await Promise.all([reconcileProfile(uid, db, identity), reconcileProfile(uid, db, identity)]);
      await expectCount(8);
    });

    await t.test('the count includes stored documents an older client cannot deserialize', async () => {
      await projects.doc('future-schema-project').set({ schemaVersion: 99 });
      await expectCount(9);
      await projects.doc('future-schema-project').delete();
      await expectCount(8);
    });

    await t.test('legacy replacement is repaired without resetting its settings', async () => {
      const prefs = { ...defaultPreferences, haptics: false, crashReports: false };
      await profile.set({ schemaVersion: 1, marketingOptIn: true, preferences: prefs, updatedAt: FieldValue.serverTimestamp() });
      await eventually(async () => {
        const data = (await profile.get()).data();
        assert.equal(data.name, 'Renamed Account');
        assert.equal(data.projectCount, 8);
        assert.equal(data.marketingOptIn, true);
        assert.deepEqual(data.preferences, prefs);
      }, 'legacy metadata repair');
    });

    await t.test('provider data handles email, Google, Apple relay, and absent Apple name', async () => {
      for (const account of [
        { displayName: 'Email User', email },
        { displayName: 'Google User', email: 'google@example.test' },
        { displayName: 'Apple User', email: 'private@privaterelay.appleid.com' },
        { displayName: null, email: 'private@privaterelay.appleid.com' },
      ]) await reconcileProfile(uid, db, async () => account);
      const data = (await profile.get()).data();
      assert.equal(data.name, 'Apple User');
      assert.equal(data.email, 'private@privaterelay.appleid.com');
      const fresh = 'missing-provider-identity';
      await reconcileProfile(fresh, db, async () => ({ displayName: null, email: null }), true);
      assert.equal((await db.doc(`users/${fresh}`).get()).get('name'), null);
      assert.equal((await db.doc(`users/${fresh}`).get()).get('projectCount'), 0);
      await callable('ensureUserProfile', token);
    });

    await t.test('an identity lookup failure leaves profile and projects unchanged', async () => {
      const before = (await profile.get()).data();
      await assert.rejects(reconcileProfile(uid, db, async () => { throw new Error('offline'); }));
      assert.deepEqual((await profile.get()).data(), before);
      assert.equal((await projects.get()).size, 8);
    });

    await t.test('rules allow old and new settings saves but deny forged metadata and cross-account access', async () => {
      env = await initializeTestEnvironment({ projectId, firestore: { rules: await readFile(new URL('../../firestore.rules', import.meta.url), 'utf8') } });
      const ownerDoc = doc(env.authenticatedContext(uid).firestore(), `users/${uid}`);
      const otherDoc = doc(env.authenticatedContext('other-account').firestore(), `users/${uid}`);
      await assertSucceeds(setDoc(ownerDoc, writableProfile(), { merge: true }));
      for (const extra of [{ name: 'forged' }, { email: 'forged@example.test' }, { projectCount: 900 }, { plan: 'pro' }]) {
        await assertFails(setDoc(ownerDoc, writableProfile(extra), { merge: true }));
      }
      await assertFails(getDoc(otherDoc));
      await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), `users/${uid}`)));
      await assertFails(getDoc(doc(env.authenticatedContext(uid).firestore(), `profileSyncState/${uid}`)));
      await assertFails(setDoc(doc(env.authenticatedContext('new-account').firestore(), 'users/new-account'), writableProfile({ projectCount: 0 })));
      await assertSucceeds(setDoc(ownerDoc, writableProfile({ marketingOptIn: true })));
      await eventually(async () => assert.equal((await profile.get()).get('projectCount'), 8), 'legacy rule-compatible repair');
      assert.equal((await callable('ensureUserProfile', null)).code, 401);
    });

    await t.test('suspension blocks in-flight repair, can resume after failure, and expires', async () => {
      assert.equal((await callable('setProfileDeletionState', token, { suspended: true })).result.status, 'synced');
      const before = (await profile.get()).data();
      assert.equal((await callable('ensureUserProfile', token)).result.status, 'suspended');
      assert.deepEqual((await profile.get()).data(), before);
      await callable('setProfileDeletionState', token, { suspended: false });
      assert.equal((await callable('ensureUserProfile', token)).result.status, 'synced');
      await db.doc(`profileSyncState/${uid}`).set({ suspendedUntil: Timestamp.fromMillis(1) });
      assert.equal((await callable('ensureUserProfile', token)).result.status, 'synced');
    });

    await t.test('bulk deletion reaches zero and late triggers cannot resurrect a deleted profile', async () => {
      const batch = db.batch();
      for (const item of (await projects.get()).docs) batch.delete(item.ref);
      await batch.commit(); await expectCount(0);
      await projects.doc('single-project').set(project('single-project')); await expectCount(1);
      await projects.doc('single-project').delete(); await expectCount(0);
      await setProfileSuspended(uid, db, true);
      await profile.delete();
      assert.equal(await reconcileProfile(uid, db, identity, true), 'suspended');
      await auth.deleteUser(uid);
      await projects.doc('late-project-event').set(project('late-project-event'));
      await projects.doc('late-project-event').delete();
      await delay(800);
      assert.equal((await profile.get()).exists, false);
      assert.equal((await db.doc('users/other-account').get()).get('projectCount'), undefined);
      await setProfileSuspended(uid, db, false);
      assert.equal(await reconcileProfile(uid, db, identity), 'missing');
      await assert.rejects(reconcileProfile(uid, db, identity, true));
      assert.equal((await profile.get()).exists, false);
    });
  } finally {
    if (env) await env.cleanup();
    await deleteApp(app);
  }
});
