import { test } from 'node:test';
import assert from 'node:assert/strict';
import { affectedAccounts, normalizeEntitlement, shouldReplace, subscriptionSnapshot } from '../lib/entitlements.js';
const now = Date.parse('2026-10-09T00:00:00Z');
import { customer } from './fixtures.js';
test('canonical trials, renewals, cancellation, expiration, refunds and grace', () => {
  const trial = normalizeEntitlement(customer(now + 86400000, {period_type: 'trial'}), now);
  assert.equal(trial.plan, 'pro'); assert.equal(trial.period, 'monthly'); assert.equal(trial.trialEndsAtMs, now + 86400000);
  assert.equal(normalizeEntitlement(customer(), now).willRenew, true);
  assert.equal(normalizeEntitlement(customer(null), now).plan, 'pro');
  assert.equal(normalizeEntitlement(customer(now + 86400000, {unsubscribe_detected_at: '2026-10-01'}), now).willRenew, false);
  const expired = normalizeEntitlement(customer(now - 1), now);
  assert.equal(expired.plan, 'free'); assert.equal(expired.lapsed, true);
  assert.equal(normalizeEntitlement({subscriber: {entitlements: {}}}, now).plan, 'free');
  assert.equal(normalizeEntitlement(customer(now - 1, {grace_period_expires_date: new Date(now + 60000).toISOString()}), now).plan, 'pro');
  const malformed = customer(); malformed.subscriber.entitlements.pro.expires_date = 'invalid';
  assert.equal(normalizeEntitlement(malformed, now).plan, 'free');
});
test('transfers reconcile both accounts once, excluding anonymous and invalid IDs', () => {
  assert.deepEqual(affectedAccounts({app_user_id: 'b', aliases: ['b', '$RCAnonymousID:x'], transferred_from: ['a'], transferred_to: ['b','bad/id']}), ['b','a']);
});
test('delayed results cannot overwrite newer canonical results; duplicates are stable', () => {
  const next = normalizeEntitlement(customer(), now);
  assert.equal(shouldReplace({...next, sourceUpdatedAtMs: now + 1}, next), false);
  assert.equal(shouldReplace(next, next), true);
});

test('subscription snapshot reflects verified RevenueCat trial, grace, expiry and empty history', () => {
  const trialCustomer = customer(now + 86400000, {
    period_type: 'trial', store: 'play_store', is_sandbox: true,
    expires_date: new Date(now + 86400000).toISOString(),
  });
  const trial = subscriptionSnapshot('owner', trialCustomer,
    normalizeEntitlement(trialCustomer, now), now);
  assert.equal(trial.status, 'trialing');
  assert.equal(trial.subKey, 'revenuecat:lastreel:monthly');
  assert.equal(trial.store, 'play_store');
  assert.equal(trial.isSandbox, true);
  assert.equal(trial.currentPeriodEnd.getTime(), now + 86400000);
  const graceCustomer = customer(now - 1, {
    expires_date: new Date(now - 1).toISOString(),
    grace_period_expires_date: new Date(now + 60000).toISOString(),
  });
  assert.equal(subscriptionSnapshot('owner', graceCustomer,
    normalizeEntitlement(graceCustomer, now), now).status, 'grace');
  const expiredCustomer = customer(now - 1, { expires_date: new Date(now - 1).toISOString() });
  assert.equal(subscriptionSnapshot('owner', expiredCustomer,
    normalizeEntitlement(expiredCustomer, now), now).status, 'expired');
  const refundedCustomer = customer(now + 86400000, {
    expires_date: new Date(now + 86400000).toISOString(), refunded_at: new Date(now).toISOString(),
  });
  refundedCustomer.subscriber.entitlements = {};
  assert.equal(subscriptionSnapshot('owner', refundedCustomer,
    normalizeEntitlement(refundedCustomer, now), now).status, 'refunded');
  const emptyCustomer = { subscriber: { entitlements: {}, subscriptions: {} } };
  const empty = subscriptionSnapshot('owner', emptyCustomer,
    normalizeEntitlement(emptyCustomer, now), now);
  assert.equal(empty.status, 'none');
  assert.equal(empty.subKey, null);
  assert.equal(empty.currentPeriodEnd, null);
});
