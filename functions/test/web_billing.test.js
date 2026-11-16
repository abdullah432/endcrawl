import { test } from 'node:test';
import assert from 'node:assert/strict';
import { checkoutUrl, managementUrl, priceOffer, sandboxAllowed } from '../lib/web_billing.js';
import { normalizeEntitlement } from '../lib/entitlements.js';

const config = { mode: 'sandbox', purchaseLink: 'https://pay.rev.cat/sandboxToken', monthlyPriceId: 'pri_monthly', yearlyPriceId: 'pri_yearly' };
test('hosted checkout uses verified identity, selected package and only the configured RevenueCat host', () => {
  const url = new URL(checkoutUrl(config, 'firebase-user', 'yearly'));
  assert.equal(url.pathname, '/sandboxToken/firebase-user');
  assert.equal(url.searchParams.get('package_id'), '$rc_annual');
  assert.throws(() => checkoutUrl(config, 'someone/else', 'yearly'));
  assert.throws(() => checkoutUrl(config, 'owner', 'free'));
  assert.throws(() => checkoutUrl({ ...config, mode: 'off' }, 'owner', 'monthly'));
  for (const link of ['https://pay.rev.cat.evil.test/token', 'http://pay.rev.cat/token', 'https://pay.rev.cat/token/victim', 'https://pay.rev.cat/token?app_user_id=victim', 'https://user:pass@pay.rev.cat/token']) {
    assert.throws(() => checkoutUrl({ ...config, purchaseLink: link }, 'owner', 'monthly'));
  }
  assert.equal(sandboxAllowed('owner', 'one, owner ,two'), true);
  assert.equal(sandboxAllowed('other', 'owner'), false);
  assert.equal(sandboxAllowed('', ''), false);
});
test('billing portal allows known provider HTTPS URLs and rejects lookalikes', () => {
  assert.equal(managementUrl('https://customer-portal.paddle.com/cpl_123?token=temporary'), 'https://customer-portal.paddle.com/cpl_123?token=temporary');
  for (const value of ['javascript:alert(1)', 'https://customer-portal.paddle.com.evil.test/', 'https://evil.test/', 'https://user@customer-portal.paddle.com/', 'https://customer-portal.paddle.com:8000/', null]) assert.equal(managementUrl(value), null);
});
test('catalog requires active recurring prices without unimplemented trials and uses currency minor units', () => {
  const price = { id: 'pri_monthly', status: 'active', billing_cycle: { interval: 'month', frequency: 1 }, trial_period: null, unit_price: { amount: '499', currency_code: 'USD' } };
  assert.equal(priceOffer(price, 'pri_monthly', 'monthly').price, 'USD 4.99');
  assert.equal(priceOffer({ ...price, unit_price: {amount:'500',currency_code:'JPY'} }, 'pri_monthly', 'monthly').price, 'JPY 500');
  assert.throws(() => priceOffer(price, 'pri_other', 'monthly'));
  assert.throws(() => priceOffer(price, 'pri_monthly', 'yearly'));
  assert.throws(() => priceOffer({ ...price, status: 'archived' }, 'pri_monthly', 'monthly'));
  assert.throws(() => priceOffer({ ...price, trial_period: { interval:'day',frequency:7 } }, 'pri_monthly', 'monthly'));
});
test('Paddle price mapping, sandbox isolation, paid-store fallback and portal token exclusion', () => {
  const now = Date.now();
  const end = new Date(now + 86400000).toISOString();
  const body = { subscriber: {
    management_url: 'https://customer-portal.paddle.com/customer?token=secret',
    entitlements: { pro: { product_identifier: 'pri_monthly', expires_date: end } },
    subscriptions: { pri_monthly: { store: 'paddle', is_sandbox: true, expires_date: end } },
  } };
  const options = { paddlePricePeriods: { pri_monthly: 'monthly' } };
  assert.equal(normalizeEntitlement(body, now, options).plan, 'free');
  const allowed = normalizeEntitlement(body, now, { ...options, allowSandboxPaddle:true });
  assert.equal(allowed.plan, 'pro');
  assert.equal(allowed.period, 'monthly');
  assert.equal(allowed.billingStore, 'paddle');
  assert.equal(allowed.managementUrl, null);
  body.subscriber.subscriptions['lastreel_pro:yearly'] = { store:'play_store', expires_date:end };
  const fallback = normalizeEntitlement(body, now, options);
  assert.equal(fallback.plan, 'pro');
  assert.equal(fallback.period, 'yearly');
  assert.equal(fallback.billingStore, 'play_store');
});
