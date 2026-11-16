import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { apiKey, enabled, loadCustomer } from './billing_functions.js';
import { normalizeEntitlement } from './entitlements.js';
import { allowsSandboxPaddle, paddlePricePeriods, webBillingConfig } from './web_billing_config.js';
import { checkoutUrl, managementUrlForStore, priceOffer, type WebPeriod } from './web_billing.js';

const paddleKey = defineSecret('PADDLE_API_KEY');
function account(auth: { uid: string } | undefined) {
  if (!auth) throw new HttpsError('unauthenticated', 'Sign in to manage your subscription.');
  if (!enabled(auth.uid)) throw new HttpsError('failed-precondition', 'Billing is not enabled for this account yet.');
  return auth.uid;
}
async function price(id: string, sandbox: boolean) {
  if (!/^pri_[a-z0-9]+$/.test(id)) throw new Error('Missing Paddle price');
  const key = paddleKey.value();
  if (!key.includes(sandbox ? '_sdbx_' : '_live_')) throw new Error('Mismatched Paddle environment');
  const response = await fetch(`https://${sandbox ? 'sandbox-api' : 'api'}.paddle.com/prices/${id}`, {
    headers: { Authorization: `Bearer ${key}`, 'Paddle-Version': '1' }, signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new Error('Could not load Paddle price');
  return (await response.json()).data;
}

export const getWebBillingOptions = onCall({ region: 'us-central1', secrets: [paddleKey] }, async request => {
  const uid = account(request.auth);
  const config = webBillingConfig(uid);
  if (config.mode === 'off') return { enabled: false, offers: [] };
  try {
    // Validate the configured hosted link before displaying any purchasable plans.
    checkoutUrl(config, uid, 'monthly');
    const offers = await Promise.all((['monthly', 'yearly'] as WebPeriod[]).map(async period => {
      const id = period === 'monthly' ? config.monthlyPriceId : config.yearlyPriceId;
      return priceOffer(await price(id, config.mode === 'sandbox'), id, period);
    }));
    const [monthly, yearly] = offers;
    const savings = monthly.currency === yearly.currency
      ? Math.floor((1 - yearly.amountMinor / (monthly.amountMinor * 12)) * 100) : 0;
    return { enabled: true, environment: config.mode, offers: offers.map(offer => ({
      ...offer, badge: offer.period === 'yearly' && savings > 0 ? `BEST VALUE · SAVE ${savings}%` : null,
    })) };
  } catch { throw new HttpsError('unavailable', 'Web plans are temporarily unavailable. Please try again.'); }
});

export const createWebCheckout = onCall({ region: 'us-central1', secrets: [apiKey] }, async request => {
  const uid = account(request.auth);
  const config = webBillingConfig(uid);
  if (config.mode === 'off') throw new HttpsError('failed-precondition', 'Web checkout is not available for this account yet.');
  if (request.data?.period !== 'monthly' && request.data?.period !== 'yearly') {
    throw new HttpsError('invalid-argument', 'Choose monthly or yearly billing.');
  }
  try {
    const entitlement = normalizeEntitlement(await loadCustomer(uid), Date.now(), {
      allowSandboxPaddle: allowsSandboxPaddle(uid), paddlePricePeriods: paddlePricePeriods(),
    });
    if (entitlement.plan === 'pro') throw new HttpsError('already-exists', 'You already have Pro. Manage your existing subscription instead.');
    return { url: checkoutUrl(config, uid, request.data.period) };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('unavailable', 'Could not open checkout. Please try again.');
  }
});

export const getBillingManagementUrl = onCall({ region: 'us-central1', secrets: [apiKey] }, async request => {
  const uid = account(request.auth);
  try {
    const customer = await loadCustomer(uid);
    const entitlement = normalizeEntitlement(customer, Date.now(), {
      allowSandboxPaddle: allowsSandboxPaddle(uid), paddlePricePeriods: paddlePricePeriods(),
    });
    const url = entitlement.plan === 'pro' ? managementUrlForStore(customer.subscriber.management_url, entitlement.billingStore) : null;
    if (!url) throw new HttpsError('not-found', 'No billing portal is available. Please contact support.');
    return { url };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('unavailable', 'Could not open billing. Please try again.');
  }
});
