import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { reconcileEntitlement } from '../lib/reconcile.js';
import { customer } from './fixtures.js';

test('emulator: owner reads, client writes denied, transfers and delayed reconciliation', {skip: !process.env.FIRESTORE_EMULATOR_HOST}, async () => {
  const projectId = 'demo-lastreel-billing';
  const env = await initializeTestEnvironment({projectId, firestore: {rules: await readFile('../firestore.rules', 'utf8')}});
  const app = initializeApp({projectId}, 'billing-tests');
  const db = getFirestore(app);
  const now = Date.parse('2026-10-09T00:00:00Z');
  try {
    const active = await reconcileEntitlement('owner', db, async () => customer(), now);
    assert.equal(active.plan, 'pro');
    await assertSucceeds(getDoc(doc(env.authenticatedContext('owner').firestore(), 'billingEntitlements/owner')));
    await assertFails(getDoc(doc(env.authenticatedContext('other').firestore(), 'billingEntitlements/owner')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'billingEntitlements/owner')));
    await assertFails(setDoc(doc(env.authenticatedContext('owner').firestore(), 'billingEntitlements/owner'), {plan:'pro'}));
    const refund = {request_date_ms: now + 2, subscriber: {entitlements:{}}};
    await reconcileEntitlement('owner', db, async () => refund, now + 2);
    const delayed = await reconcileEntitlement('owner', db, async () => customer(), now + 3);
    assert.equal(delayed.plan, 'free');
    const transferred = {...customer(), request_date_ms: now + 4};
    await reconcileEntitlement('recipient', db, async () => transferred, now + 4);
    await reconcileEntitlement('recipient', db, async () => transferred, now + 4);
    assert.equal((await db.doc('billingEntitlements/recipient').get()).data().plan, 'pro');
    assert.equal((await db.doc('billingEntitlements/owner').get()).data().plan, 'free');
    await assert.rejects(reconcileEntitlement('owner', db, async () => {throw new Error('offline')}, now + 5));
    assert.equal((await db.doc('billingEntitlements/owner').get()).data().plan, 'free');
  } finally { await env.cleanup(); await deleteApp(app); }
});
