import { createHash, timingSafeEqual } from 'node:crypto';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { affectedAccounts } from './entitlements.js';
import { reconcileEntitlement } from './reconcile.js';

initializeApp();
const db = getFirestore();
const apiKey = defineSecret('REVENUECAT_SECRET_API_KEY');
const webhookAuth = defineSecret('REVENUECAT_WEBHOOK_AUTH');

async function reconcile(uid: string) {
  return reconcileEntitlement(uid, db, async (account) => {
    const response = await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(account)}`, {
      headers: { Authorization: `Bearer ${apiKey.value()}` }, signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error(`RevenueCat returned ${response.status}`);
    return response.json();
  });
}

export const refreshEntitlement = onCall({ region: 'us-central1', secrets: [apiKey] }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in to check your subscription.');
  try { return await reconcile(request.auth.uid); }
  catch { throw new HttpsError('unavailable', 'Could not check your subscription. Please try again.'); }
});

/** Acknowledge only after durable enqueueing; worker failures are retried. */
export const revenueCatWebhook = onRequest({ region: 'us-central1', secrets: [webhookAuth] }, async (request, response) => {
  const supplied = Buffer.from(request.get('Authorization') ?? '');
  const expected = Buffer.from(webhookAuth.value());
  if (request.method !== 'POST' || supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) {
    response.sendStatus(401); return;
  }
  const event = request.body?.event;
  if (typeof event?.id !== 'string') { response.sendStatus(400); return; }
  const key = createHash('sha256').update(event.id).digest('hex');
  try {
    await db.doc(`billingWebhookEvents/${key}`).create({ accounts: affectedAccounts(event), eventId: event.id,
      receivedAt: FieldValue.serverTimestamp(), processed: false });
  } catch (error: any) {
    if (error.code !== 6) { response.sendStatus(503); return; }
  }
  response.sendStatus(200);
});

export const reconcileBillingEvent = onDocumentCreated({ region: 'us-central1', document: 'billingWebhookEvents/{eventId}',
  secrets: [apiKey], retry: true }, async (event) => {
  const data = event.data?.data();
  if (!data || data.processed) return;
  for (const uid of data.accounts as string[]) {
    try { await getAuth().getUser(uid); }
    catch (error: any) { if (error.code === 'auth/user-not-found') continue; throw error; }
    await reconcile(uid);
  }
  await event.data!.ref.update({ processed: true, processedAt: FieldValue.serverTimestamp() });
});
