import { test } from 'node:test';
import assert from 'node:assert/strict';

test('web billing callables enforce Auth identity, sandbox isolation, active subscriptions and provider failures', async () => {
  process.env.GCLOUD_PROJECT = 'demo-lastreel-web-billing';
  process.env.BILLING_ROLLOUT_MODE = 'all';
  process.env.WEB_BILLING_MODE = 'sandbox';
  process.env.PADDLE_SANDBOX_UIDS = 'owner';
  process.env.REVENUECAT_SANDBOX_PURCHASE_LINK = 'https://pay.rev.cat/sandboxToken';
  process.env.PADDLE_SANDBOX_MONTHLY_PRICE_ID = 'pri_monthly';
  process.env.PADDLE_SANDBOX_YEARLY_PRICE_ID = 'pri_yearly';
  process.env.PADDLE_API_KEY = 'pdl_sdbx_apikey_emulator';
  process.env.REVENUECAT_API_KEY = 'emulator-public';
  const { getWebBillingOptions, createWebCheckout, getBillingManagementUrl } = await import('../lib/web_billing_functions.js');
  const originalFetch = globalThis.fetch;
  let subscriber = { entitlements: {}, subscriptions: {} };
  let fail = false;
  const customers = [];
  globalThis.fetch = async (input, options) => {
    const url = new URL(String(input));
    if (fail) return new Response('{}', {status:503});
    if (url.hostname === 'sandbox-api.paddle.com') {
      assert.equal(options.headers.Authorization, 'Bearer pdl_sdbx_apikey_emulator');
      assert.equal(options.headers['Paddle-Version'], '1');
      const yearly = url.pathname.endsWith('pri_yearly');
      return Response.json({ data: { id: yearly ? 'pri_yearly' : 'pri_monthly', status: 'active',
        billing_cycle: { interval: yearly ? 'year' : 'month', frequency: 1 },
        trial_period: null, unit_price: { amount: yearly ? '2999' : '499', currency_code: 'USD' } } });
    }
    assert.equal(url.hostname, 'api.revenuecat.com', 'No unexpected network destination');
    customers.push(url.pathname.split('/').at(-1));
    assert.equal(options.headers.Authorization, 'Bearer emulator-public');
    return Response.json({ request_date_ms: Date.now(), subscriber });
  };
  try {
    for (const handler of [getWebBillingOptions, createWebCheckout, getBillingManagementUrl]) {
      await assert.rejects(handler.run({data:{uid:'owner',period:'yearly'}}), {code:'unauthenticated'});
    }
    assert.equal((await getWebBillingOptions.run({auth:{uid:'other'},data:{uid:'owner'}})).enabled, false);
    await assert.rejects(createWebCheckout.run({auth:{uid:'other'},data:{uid:'owner',period:'yearly'}}), {code:'failed-precondition'});
    const catalog = await getWebBillingOptions.run({auth:{uid:'owner'},data:{}});
    assert.equal(catalog.environment, 'sandbox');
    assert.equal(catalog.offers.length, 2);
    const checkout = await createWebCheckout.run({auth:{uid:'owner'},data:{uid:'victim',period:'yearly'}});
    assert.equal(new URL(checkout.url).pathname, '/sandboxToken/owner');
    assert.deepEqual(customers, ['owner']);
    await assert.rejects(createWebCheckout.run({auth:{uid:'owner'},data:{period:'free'}}), {code:'invalid-argument'});
    const end = new Date(Date.now() + 86400000).toISOString();
    subscriber = { entitlements:{pro:{product_identifier:'pri_yearly',expires_date:end}},
      subscriptions:{pri_yearly:{store:'paddle',is_sandbox:true,expires_date:end}},
      management_url:'https://sandbox-customer-portal.paddle.com/customer?token=fresh' };
    await assert.rejects(createWebCheckout.run({auth:{uid:'owner'},data:{period:'monthly'}}), {code:'already-exists'});
    assert.equal((await getBillingManagementUrl.run({auth:{uid:'owner'},data:{uid:'victim'}})).url, subscriber.management_url);
    subscriber.management_url = 'https://attacker.test/customer';
    await assert.rejects(getBillingManagementUrl.run({auth:{uid:'owner'},data:{}}), {code:'not-found'});
    subscriber.subscriptions.lastreel_pro_monthly = {store:'play_store',is_sandbox:false,expires_date:end};
    subscriber.management_url = 'https://sandbox-customer-portal.paddle.com/customer?token=unrelated-sandbox';
    assert.equal((await getBillingManagementUrl.run({auth:{uid:'other'},data:{}})).url,
      'https://play.google.com/store/account/subscriptions', 'Preserved paid mobile access must manage the mobile store, not a disallowed sandbox subscription');
    fail = true;
    await assert.rejects(getWebBillingOptions.run({auth:{uid:'owner'},data:{}}), {code:'unavailable'});
    await assert.rejects(createWebCheckout.run({auth:{uid:'owner'},data:{period:'yearly'}}), {code:'unavailable'});
    process.env.BILLING_ROLLOUT_MODE = 'off';
    await assert.rejects(getWebBillingOptions.run({auth:{uid:'owner'},data:{}}), {code:'failed-precondition'});
  } finally { globalThis.fetch = originalFetch; }
});
