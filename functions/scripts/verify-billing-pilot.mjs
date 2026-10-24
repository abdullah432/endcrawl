// Live, account-scoped verification. Never creates a purchase or grants Pro.
import assert from 'node:assert/strict';
import { createHash, randomBytes } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { realpathSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';
import { normalizeEntitlement } from '../lib/entitlements.js';

const project = 'endcrawl-620c2';
const email = 'abdullah234ktk@gmail.com';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const billing = ['refreshEntitlement', 'revenueCatWebhook', 'reconcileBillingEvent'];
const profiles = ['ensureUserProfile', 'setProfileDeletionState', 'reconcileProjectCount', 'repairLegacyUserProfile'];
const normalize = value => Array.isArray(value) ? value.map(normalize) : value && typeof value === 'object'
  ? Object.fromEntries(Object.keys(value).sort().map(key => [key, normalize(value[key])])) : value;
const hash = value => createHash('sha256').update(JSON.stringify(normalize(value))).digest('hex');

async function verify() {
  if (!process.argv.includes('--exercise-webhook')) throw new Error('Explicit --exercise-webhook is required.');
  if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Live verification cannot use emulators.');
  const req = createRequire(realpathSync(execFileSync('which', ['firebase'], { encoding: 'utf8' }).trim()));
  const cliAuth = req('../auth.js');
  const account = cliAuth.getGlobalDefaultAccount();
  if (account?.user?.email?.toLowerCase() !== email) throw new Error('Firebase CLI must use the designated account.');
  const { access_token: token } = await cliAuth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
  async function api(url, { method = 'GET', body, optional = false } = {}) {
    const response = await fetch(url, {
      method, headers: { Authorization: `Bearer ${token}`, 'x-goog-user-project': project, 'Content-Type': 'application/json' },
      ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(30000),
    });
    if (optional && response.status === 404) return null;
    if (!response.ok) throw new Error(`Read-only verification request failed: HTTP ${response.status}`);
    return response.json();
  }
  const lookup = await api(`https://identitytoolkit.googleapis.com/v1/projects/${project}/accounts:lookup`, { method: 'POST', body: { email: [email] } });
  const uid = lookup.users?.find(user => user.email?.toLowerCase() === email)?.localId;
  assert.ok(uid, 'Designated Firebase account missing');
  for (const name of [...billing, ...profiles]) {
    const functionInfo = await api(`https://cloudfunctions.googleapis.com/v2/projects/${project}/locations/us-central1/functions/${name}`);
    const prefix = billing.includes(name) ? 'BILLING' : 'PROFILE';
    assert.equal(functionInfo.state, 'ACTIVE', `${name} must be active`);
    assert.equal(functionInfo.serviceConfig?.environmentVariables?.[`${prefix}_ROLLOUT_MODE`], 'pilot', `${name} must stay pilot-only`);
    assert.equal(functionInfo.serviceConfig?.environmentVariables?.[`${prefix}_PILOT_UID`], uid, `${name} must use the real designated UID`);
  }
  console.log('PASS: all billing/profile handlers are ACTIVE and restricted to the designated UID.');
  const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
  async function projectsForAccount() {
    let pageToken = ''; const docs = [];
    do {
      const page = await api(`${base}/users/${uid}/projects?pageSize=100${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`);
      docs.push(...(page.documents ?? [])); pageToken = page.nextPageToken ?? '';
    } while (pageToken);
    return docs.sort((a, b) => a.name.localeCompare(b.name));
  }
  const before = { profile: await api(`${base}/users/${uid}`, { optional: true }),
    projects: await projectsForAccount(), ledger: await api(`${base}/billingEntitlements/${uid}`, { optional: true }) };
  const output = resolve(root, 'output/billing-pilot', `live-${new Date().toISOString().replaceAll(':', '-')}`);
  await mkdir(output, { recursive: true, mode: 0o700 });
  await writeFile(resolve(output, 'before.json'), JSON.stringify(before, null, 2), { mode: 0o600 });

  const endpoint = `https://us-central1-${project}.cloudfunctions.net`;
  const webhookSecret = await api(`https://secretmanager.googleapis.com/v1/projects/${project}/secrets/REVENUECAT_WEBHOOK_AUTH/versions/latest:access`);
  const webhookHeader = Buffer.from(webhookSecret.payload.data, 'base64').toString('utf8').trim();
  const id = `billing-pilot-check-${randomBytes(12).toString('hex')}`;
  const eventUrl = eventId => `${base}/billingWebhookEvents/${createHash('sha256').update(eventId).digest('hex')}`;
  async function webhook(header, event) {
    return fetch(`${endpoint}/revenueCatWebhook`, { method: 'POST',
      headers: { Authorization: header, 'Content-Type': 'application/json' },
      body: JSON.stringify({ event }), signal: AbortSignal.timeout(30000) });
  }
  const unauthenticated = await fetch(`${endpoint}/refreshEntitlement`, { method: 'POST',
    headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ data: {} }), signal: AbortSignal.timeout(30000) });
  assert.equal(unauthenticated.status, 401);
  assert.equal((await webhook('Bearer invalid-test-header', { id, app_user_id: uid })).status, 401);
  assert.equal(await api(eventUrl(id), { optional: true }), null);
  const ignoredUid = `billing-ignored-${randomBytes(12).toString('hex')}`;
  assert.equal((await webhook(webhookHeader, { id: `${id}-ignored`, app_user_id: ignoredUid, type: 'TEST' })).status, 200);
  assert.equal(await api(eventUrl(`${id}-ignored`), { optional: true }), null);
  assert.equal(await api(`${base}/billingEntitlements/${ignoredUid}`, { optional: true }), null);
  console.log('PASS: unauthenticated refresh and invalid webhook auth are rejected; non-pilot events make no writes.');

  assert.equal((await webhook(webhookHeader, { id, app_user_id: uid, type: 'TEST' })).status, 200);
  assert.equal((await webhook(webhookHeader, { id, app_user_id: uid, type: 'TEST' })).status, 200);
  const deadline = Date.now() + 60000;
  let event;
  do {
    event = await api(eventUrl(id), { optional: true });
    if (event?.fields?.processed?.booleanValue === true) break;
    await delay(1000);
  } while (Date.now() < deadline);
  assert.equal(event?.fields?.processed?.booleanValue, true, 'Live webhook worker did not finish');
  const source = await readFile(resolve(root, 'app/lib/core/config/billing_config.dart'), 'utf8');
  const key = /defaultValue: '(goog_[^']+)'/.exec(source)?.[1];
  assert.ok(key, 'Configured RevenueCat app key missing');
  const response = await fetch(`https://api.revenuecat.com/v1/subscribers/${uid}`, {
    headers: { Authorization: `Bearer ${key}` }, signal: AbortSignal.timeout(20000) });
  assert.ok(response.ok, 'Canonical RevenueCat lookup failed');
  const canonical = normalizeEntitlement(await response.json(), Date.now());
  const after = { profile: await api(`${base}/users/${uid}`), projects: await projectsForAccount(),
    ledger: await api(`${base}/billingEntitlements/${uid}`) };
  assert.equal(after.ledger.fields.plan.stringValue, canonical.plan, 'Ledger does not match RevenueCat');
  assert.equal(hash(after.projects), hash(before.projects), 'An original project changed');
  for (const name of ['preferences', 'marketingOptIn']) {
    assert.equal(hash(after.profile.fields[name]), hash(before.profile.fields[name]), `Existing ${name} changed`);
  }
  await writeFile(resolve(output, 'after.json'), JSON.stringify(after, null, 2), { mode: 0o600 });
  await writeFile(resolve(output, 'result.json'), JSON.stringify({ backendPassed: true, rollout: 'pilot',
    canonicalPlan: canonical.plan, projectCount: after.projects.length, originalProjectsUnchanged: true,
    settingsPreserved: true, realProDetected: canonical.plan === 'pro', interactiveEditingExportVerified: false }, null, 2), { mode: 0o600 });
  console.log(`PASS: live authenticated webhook, duplicate delivery and worker reconciliation; canonical account plan is ${canonical.plan}.`);
  console.log(`PASS: ${after.projects.length} original projects, preferences and consent are unchanged. Profile and billing rollout remain pilot-only.`);
  console.log(`Private verification artifacts: ${output}`);
}
await verify().catch(error => {
  console.error(error instanceof Error ? error.message : 'Billing pilot verification failed.');
  process.exitCode = 1;
});
