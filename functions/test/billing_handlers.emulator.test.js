import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import { customer } from './fixtures.js';

test('billing handlers: authenticated identity, rollout isolation, provider failure and webhook retry safety', {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
}, async () => {
  assert.equal(process.env.GCLOUD_PROJECT, 'demo-lastreel-profiles');
  for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST']) {
    assert.match(process.env[key] ?? '', /^127\.0\.0\.1:\d+$/);
  }
  const pilot = 'local-billing-pilot';
  const other = 'local-billing-other';
  process.env.BILLING_ROLLOUT_MODE = 'pilot';
  process.env.BILLING_PILOT_UID = pilot;
  process.env.REVENUECAT_API_KEY = 'emulator-unused';
  process.env.REVENUECAT_WEBHOOK_AUTH = 'Bearer billing-emulator-only';
  const { refreshEntitlement, revenueCatWebhook, reconcileBillingEvent } = await import('../lib/billing_functions.js');
  const { db } = await import('../lib/firebase.js');
  const { getAuth } = await import('firebase-admin/auth');
  const auth = getAuth();
  await auth.createUser({ uid: pilot, email: 'billing-pilot@example.test' });
  const pilotDoc = db.doc(`billingEntitlements/${pilot}`);
  const otherDoc = db.doc(`billingEntitlements/${other}`);
  const workerDoc = db.doc('billingHandlerFixtures/worker');
  await otherDoc.set({ plan: 'pro', untouched: true });
  const originalFetch = globalThis.fetch;
  let calls = [];
  let response = { ...customer(Date.now() + 86400000), request_date_ms: Date.now() };
  let providerFails = false;
  globalThis.fetch = async (url, options) => {
    const parsed = new URL(String(url));
    if (parsed.host === 'api.revenuecat.com') {
      calls.push(decodeURIComponent(parsed.pathname.split('/').at(-1)));
      assert.equal(options.headers.Authorization, 'Bearer emulator-unused');
      if (providerFails) return new Response('{}', { status: 503 });
      return Response.json(response);
    }
    assert.ok(['localhost', '127.0.0.1'].includes(parsed.hostname), 'Test refused a production request');
    return originalFetch(url, options);
  };
  const eventId = `billing-handler-${Date.now()}`;
  const eventDoc = db.doc(`billingWebhookEvents/${createHash('sha256').update(eventId).digest('hex')}`);
  async function webhook(header, event) {
    let code;
    await revenueCatWebhook({ method: 'POST', headers: {}, get: () => header, body: { event } }, {
      sendStatus: value => { code = value; },
    });
    return code;
  }
  try {
    await assert.rejects(refreshEntitlement.run({ data: { uid: pilot } }), { code: 'unauthenticated' });
    await assert.rejects(refreshEntitlement.run({ auth: { uid: other }, data: { uid: pilot } }), { code: 'failed-precondition' });
    assert.deepEqual(calls, []);
    assert.equal((await pilotDoc.get()).exists, false);
    const pro = await refreshEntitlement.run({ auth: { uid: pilot }, data: { uid: other, plan: 'pro' } });
    assert.equal(pro.plan, 'pro');
    assert.deepEqual(calls, [pilot]);
    assert.deepEqual((await otherDoc.get()).data(), { plan: 'pro', untouched: true });
    const savedPro = (await pilotDoc.get()).data();
    providerFails = true;
    await assert.rejects(refreshEntitlement.run({ auth: { uid: pilot }, data: {} }), { code: 'unavailable' });
    assert.deepEqual((await pilotDoc.get()).data(), savedPro);
    providerFails = false;
    response = {};
    await assert.rejects(refreshEntitlement.run({ auth: { uid: pilot }, data: {} }), { code: 'unavailable' });
    assert.deepEqual((await pilotDoc.get()).data(), savedPro);

    response = { request_date_ms: Date.now() + 10, subscriber: { entitlements: {}, subscriptions: {} } };
    await workerDoc.set({ accounts: [other, pilot], processed: false });
    calls = [];
    await reconcileBillingEvent.run({ data: await workerDoc.get() });
    assert.deepEqual(calls, [pilot]);
    assert.equal((await pilotDoc.get()).get('plan'), 'free');
    assert.deepEqual((await otherDoc.get()).data(), { plan: 'pro', untouched: true });
    assert.equal((await workerDoc.get()).get('processed'), true);
    await reconcileBillingEvent.run({ data: await workerDoc.get() });
    assert.deepEqual(calls, [pilot]);

    assert.equal(await webhook('wrong', { id: eventId, app_user_id: pilot }), 401);
    assert.equal((await eventDoc.get()).exists, false);
    assert.equal(await webhook('Bearer billing-emulator-only', { id: eventId, app_user_id: other }), 200);
    assert.equal((await eventDoc.get()).exists, false);
    const event = { id: eventId, app_user_id: pilot, aliases: [other] };
    assert.equal(await webhook('Bearer billing-emulator-only', event), 200);
    assert.deepEqual((await eventDoc.get()).get('accounts'), [pilot]);
    // Let the real emulator's default-off worker acknowledge this fixture before
    // removing it; deleting earlier races its final durable acknowledgement.
    const deadline = Date.now() + 10000;
    while (!(await eventDoc.get()).get('processed') && Date.now() < deadline) await delay(100);
    assert.equal((await eventDoc.get()).get('processed'), true);
    assert.equal(await webhook('Bearer billing-emulator-only', event), 200);
    assert.deepEqual((await eventDoc.get()).get('accounts'), [pilot]);
  } finally {
    globalThis.fetch = originalFetch;
    await Promise.all([pilotDoc.delete(), otherDoc.delete(), workerDoc.delete(), eventDoc.delete()]);
    await auth.deleteUser(pilot);
  }
});
