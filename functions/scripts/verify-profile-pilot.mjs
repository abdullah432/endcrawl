// Explicit live verification of the designated account only. Tokens stay in
// memory; errors never dump request/response objects or customer project data.
import assert from 'node:assert/strict';
import { randomBytes, createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { realpathSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';
import { defaultPreferences } from '../lib/profiles.js';

const project = 'endcrawl-620c2';
const email = 'abdullah234ktk@gmail.com';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const functions = ['ensureUserProfile', 'setProfileDeletionState', 'reconcileProjectCount', 'repairLegacyUserProfile'];
const normalize = value => Array.isArray(value) ? value.map(normalize) : value && typeof value === 'object'
  ? Object.fromEntries(Object.keys(value).sort().map(key => [key, normalize(value[key])])) : value;
const hash = value => createHash('sha256').update(JSON.stringify(normalize(value))).digest('hex');

async function verify() {
  const adminMode = process.argv.includes('--admin-exercise');
  if (!adminMode) throw new Error('Explicit --admin-exercise is required. Interactive app sign-in is verified separately.');
  if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Live verification cannot use emulator hosts.');
  const req = createRequire(realpathSync(execFileSync('which', ['firebase'], { encoding: 'utf8' }).trim()));
  const auth = req('../auth.js');
  const account = auth.getGlobalDefaultAccount();
  if (account?.user?.email?.toLowerCase() !== email) throw new Error('Firebase CLI must be signed in as the designated pilot account.');
  const { access_token: googleToken } = await auth.getAccessToken(account.tokens.refresh_token, [
    'https://www.googleapis.com/auth/cloud-platform', 'https://www.googleapis.com/auth/userinfo.email', 'openid',
  ]);
  async function api(url, { method = 'GET', body, token = googleToken, optional = false, label = 'Pilot request' } = {}) {
    const response = await fetch(url, {
      method, headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', 'x-goog-user-project': project },
      ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(45_000),
    });
    if (optional && response.status === 404) return null;
    if (!response.ok) {
      const data = await response.json().catch(() => ({}));
      const code = /^[A-Z_0-9]+/.exec(data.error?.message ?? '')?.[0] ?? '';
      throw new Error(`${label}: HTTP ${response.status}${code ? ` (${code})` : ''}`);
    }
    return response.status === 204 ? null : response.json();
  }
  const lookup = await api(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:lookup`, {
    method: 'POST', body: { email: [email] }, label: 'Pilot identity lookup',
  });
  const user = lookup.users?.find(user => user.email?.toLowerCase() === email);
  if (!user?.localId || !(user.providerUserInfo ?? []).some(provider => provider.providerId === 'google.com')) {
    throw new Error('Designated existing Google account was not found.');
  }
  const uid = user.localId;
  for (const name of functions) {
    const deployed = await api(`https://cloudfunctions.googleapis.com/v2/projects/${project}/locations/us-central1/functions/${name}`, { label: `${name} deployment inspection` });
    if (deployed.state !== 'ACTIVE' || deployed.serviceConfig?.environmentVariables?.PROFILE_ROLLOUT_MODE !== 'pilot' ||
        deployed.serviceConfig?.environmentVariables?.PROFILE_PILOT_UID !== uid) {
      throw new Error(`${name} must be ACTIVE and restricted to the designated pilot UID.`);
    }
  }
  console.log('PASS: all four deployed functions are ACTIVE and restricted to the pilot UID.');

  const database = `projects/${project}/databases/(default)`;
  const base = `https://firestore.googleapis.com/v1/${database}/documents`;
  const profilePath = `users/${uid}`;
  const profileUrl = `${base}/${profilePath}`;
  const projectsUrl = `${profileUrl}/projects`;
  async function readProjects() {
    const docs = [];
    let pageToken = '';
    do {
      const page = await api(`${projectsUrl}?pageSize=100${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`);
      docs.push(...(page.documents ?? [])); pageToken = page.nextPageToken ?? '';
    } while (pageToken);
    return docs.sort((a, b) => a.name.localeCompare(b.name));
  }
  const before = { identity: { uid, email, name: user.displayName ?? null },
    profile: await api(profileUrl, { optional: true }), projects: await readProjects() };
  const output = resolve(root, 'output/profile-pilot', `live-${new Date().toISOString().replaceAll(':', '-')}`);
  await mkdir(output, { recursive: true, mode: 0o700 });
  await writeFile(resolve(output, 'before.json'), JSON.stringify(before, null, 2), { mode: 0o600 });

  const token = googleToken;
  const encode = value => {
    if (typeof value === 'boolean') return { booleanValue: value };
    if (typeof value === 'number') return { integerValue: String(value) };
    if (typeof value === 'string') return { stringValue: value };
    return { mapValue: { fields: Object.fromEntries(Object.entries(value).map(([key, item]) => [key, encode(item)])) } };
  };
  const guard = await api(`${base}/profileSyncState/${uid}`, { optional: true });
  if (Date.parse(guard?.fields?.suspendedUntil?.timestampValue ?? '') > Date.now()) throw new Error('Account deletion guard is active; refusing pilot writes.');
  // Reproduce an older client's profile save to exercise the deployed repair
  // worker. Preserve every existing setting, consent value, and extra field.
  const initialFields = { ...(before.profile?.fields ?? {}),
    schemaVersion: before.profile?.fields.schemaVersion ?? { integerValue: '1' },
    preferences: before.profile?.fields.preferences ?? encode(defaultPreferences),
    marketingOptIn: before.profile?.fields.marketingOptIn ?? { booleanValue: false },
  };
  for (const key of ['name', 'email', 'projectCount', 'updatedAt']) delete initialFields[key];
  await api(`https://firestore.googleapis.com/v1/${database}/documents:commit`, {
    method: 'POST', label: 'Pilot legacy profile save', body: { writes: [{
      update: { name: `${database}/documents/${profilePath}`, fields: initialFields },
      updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
      currentDocument: before.profile ? { updateTime: before.profile.updateTime } : { exists: false },
    }] },
  });
  const expected = before.projects.length;
  async function expectProfile(count) {
    const deadline = Date.now() + 45_000;
    do {
      const doc = await api(profileUrl, { optional: true });
      if (doc?.fields?.email?.stringValue === email && doc.fields.projectCount?.integerValue === String(count) &&
          (doc.fields.name?.stringValue ?? null) === (user.displayName ?? null)) return doc;
      await delay(1000);
    } while (Date.now() < deadline);
    throw new Error('Pilot identity/count did not converge before the deadline.');
  }
  let current = await expectProfile(expected);
  if (before.profile) {
    for (const field of ['preferences', 'marketingOptIn']) assert.equal(hash(current.fields[field]), hash(before.profile.fields[field]), `Existing ${field} changed`);
  }
  console.log(`PASS: deployed profile worker populated the Auth name/email and count of ${expected} projects.`);

  const testId = randomBytes(15).toString('base64url').slice(0, 20);
  const testUrl = `${projectsUrl}/${testId}`;
  let created = false;
  const originalSettings = current.fields.preferences;
  const originalConsent = current.fields.marketingOptIn;
  const commitUrl = `https://firestore.googleapis.com/v1/${database}/documents:commit`;
  const commitSettings = async (fields, updateMask) => api(commitUrl, { method: 'POST', token, label: 'Pilot settings save', body: { writes: [{
    update: { name: `${database}/documents/${profilePath}`, fields },
    ...(updateMask ? { updateMask: { fieldPaths: updateMask } } : {}),
    updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }], currentDocument: { exists: true },
  }] } });
  try {
    const timestamp = new Date().toISOString();
    const fields = {
      schemaVersion: { integerValue: '2' }, id: { stringValue: testId }, ownerId: { stringValue: uid },
      title: { stringValue: 'Profile pilot verification (temporary)' },
      settings: before.projects[0]?.fields.settings ?? { mapValue: { fields: {} } },
      blocks: { arrayValue: { values: [] } }, createdAt: { timestampValue: timestamp }, updatedAt: { timestampValue: timestamp },
    };
    await api(`${projectsUrl}?documentId=${testId}`, { method: 'POST', token, body: { fields }, label: 'Temporary pilot project creation' });
    created = true;
    await expectProfile(expected + 1);
    await api(`${testUrl}?updateMask.fieldPaths=title`, { method: 'PATCH', token,
      body: { fields: { title: { stringValue: 'Profile pilot verification edited' } } }, label: 'Temporary pilot project edit' });
    await expectProfile(expected + 1);
    await api(testUrl, { method: 'DELETE', token, label: 'Temporary pilot project cleanup' });
    created = false;
    await expectProfile(expected);
    console.log('PASS: live create/edit/delete and project-count triggers; temporary project removed.');

    const originalHaptics = originalSettings.mapValue.fields.haptics;
    await commitSettings({ preferences: { mapValue: { fields: { haptics: { booleanValue: !originalHaptics.booleanValue } } } } }, ['preferences.haptics']);
    await expectProfile(expected);
    await commitSettings({ preferences: originalSettings }, ['preferences']);
    // Exercise the exact legacy full replacement: server metadata must be repaired.
    await commitSettings({ schemaVersion: { integerValue: '1' }, preferences: originalSettings, marketingOptIn: originalConsent });
    current = await expectProfile(expected);
    assert.equal(hash(current.fields.preferences), hash(originalSettings), 'Settings were not preserved');
    assert.equal(hash(current.fields.marketingOptIn), hash(originalConsent), 'Consent was not preserved');
    console.log('PASS: live settings merge and legacy replacement repair; original settings and consent restored.');
  } finally {
    if (created) await api(testUrl, { method: 'DELETE', token, label: 'Temporary pilot project final cleanup' });
    // This also restores settings if a test failed between the two saves.
    await commitSettings({ preferences: originalSettings, marketingOptIn: originalConsent }, ['preferences', 'marketingOptIn']);
  }
  const after = { profile: await expectProfile(expected), projects: await readProjects() };
  assert.equal(hash(after.projects), hash(before.projects), 'An existing project changed during verification');
  assert.equal(hash(after.profile.fields.preferences), hash(originalSettings), 'Final preferences differ');
  assert.equal(hash(after.profile.fields.marketingOptIn), hash(originalConsent), 'Final consent differs');
  await writeFile(resolve(output, 'after.json'), JSON.stringify(after, null, 2), { mode: 0o600 });
  await writeFile(resolve(output, 'result.json'), JSON.stringify({ passed: true, project, uid,
    projectCount: expected, existingProjectsUnchanged: true, preferencesPreserved: true, rollout: 'pilot',
    verificationMode: 'administrator-backend-exercise', interactiveSignInVerified: false, functions }, null, 2), { mode: 0o600 });
  console.log(`PASS: all ${expected} original projects are byte-equivalent in Firestore snapshots; rollout remains pilot-only.`);
  console.log(`Private live verification artifacts: ${output}`);
}
await verify().catch(error => {
  // Only errors explicitly constructed here have safe messages. Assertion errors
  // contain hashes only. Never serialize SDK errors, tokens, or customer content.
  const message = error instanceof Error ? error.message : 'Unknown verification failure';
  console.error(`Live pilot verification stopped: ${message.replace(/Bearer\s+\S+/g, 'Bearer [REDACTED]')}`);
  process.exitCode = 1;
});
