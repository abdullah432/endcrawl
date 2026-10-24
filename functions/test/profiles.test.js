import { test } from 'node:test';
import assert from 'node:assert/strict';
import { profileEnabled, hasProfileMetadata } from '../lib/profiles.js';

test('profile rollout fails closed and pilot matches only the configured UID', () => {
  for (const mode of ['', 'off', 'invalid', 'ALL']) {
    assert.equal(profileEnabled('pilot', { mode, pilotUid: 'pilot' }), false);
  }
  assert.equal(profileEnabled('pilot', { mode: 'pilot', pilotUid: '' }), false);
  assert.equal(profileEnabled('pilot', { mode: 'pilot', pilotUid: 'pilot' }), true);
  assert.equal(profileEnabled('other', { mode: 'pilot', pilotUid: 'pilot' }), false);
  assert.equal(profileEnabled('other', { mode: 'all', pilotUid: '' }), true);
});

test('metadata completeness permits missing provider identity but requires a valid count', () => {
  assert.equal(hasProfileMetadata({ name: null, email: null, projectCount: 0 }), true);
  for (const projectCount of [-1, 0.5, '2', null, undefined]) {
    assert.equal(hasProfileMetadata({ name: null, email: null, projectCount }), false);
  }
  assert.equal(hasProfileMetadata({ email: 'apple@privaterelay.appleid.com', projectCount: 1 }), false);
});
