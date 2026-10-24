import { test } from 'node:test';
import assert from 'node:assert/strict';
import { billingEnabled } from '../lib/billing_rollout.js';

test('billing rollout fails closed and restricts pilot writes to the administrator UID', () => {
  for (const mode of ['', 'off', 'unknown', 'PILOT']) {
    assert.equal(billingEnabled('pilot', { mode, pilotUid: 'pilot' }), false);
  }
  assert.equal(billingEnabled('pilot', { mode: 'pilot', pilotUid: '' }), false);
  assert.equal(billingEnabled('pilot', { mode: 'pilot', pilotUid: 'pilot' }), true);
  assert.equal(billingEnabled('another-account', { mode: 'pilot', pilotUid: 'pilot' }), false);
  assert.equal(billingEnabled('', { mode: 'all', pilotUid: '' }), false);
  assert.equal(billingEnabled('another-account', { mode: 'all', pilotUid: '' }), true);
});
