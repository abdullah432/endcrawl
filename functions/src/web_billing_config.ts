import { defineString } from 'firebase-functions/params';
import { sandboxAllowed, type WebBillingConfig } from './web_billing.js';

const mode = defineString('WEB_BILLING_MODE', { default: 'off' });
const sandboxUids = defineString('PADDLE_SANDBOX_UIDS', { default: '' });
const sandboxLink = defineString('REVENUECAT_SANDBOX_PURCHASE_LINK', { default: '' });
const liveLink = defineString('REVENUECAT_LIVE_PURCHASE_LINK', { default: '' });
const sandboxMonthly = defineString('PADDLE_SANDBOX_MONTHLY_PRICE_ID', { default: '' });
const sandboxYearly = defineString('PADDLE_SANDBOX_YEARLY_PRICE_ID', { default: '' });
const liveMonthly = defineString('PADDLE_LIVE_MONTHLY_PRICE_ID', { default: '' });
const liveYearly = defineString('PADDLE_LIVE_YEARLY_PRICE_ID', { default: '' });

export function allowsSandboxPaddle(uid: string) { return sandboxAllowed(uid, sandboxUids.value()); }
export function paddlePricePeriods(): Record<string, 'monthly' | 'yearly'> {
  return Object.fromEntries([
    [sandboxMonthly.value(), 'monthly'], [liveMonthly.value(), 'monthly'],
    [sandboxYearly.value(), 'yearly'], [liveYearly.value(), 'yearly'],
  ].filter(([id]) => id.length > 0));
}
export function webBillingConfig(uid: string): WebBillingConfig {
  const selected = mode.value();
  if (!['off', 'sandbox', 'live'].includes(selected)) throw new Error('Invalid billing environment');
  const sandbox = selected === 'sandbox';
  return {
    mode: sandbox && !allowsSandboxPaddle(uid) ? 'off' : selected as WebBillingConfig['mode'],
    purchaseLink: sandbox ? sandboxLink.value() : liveLink.value(),
    monthlyPriceId: sandbox ? sandboxMonthly.value() : liveMonthly.value(),
    yearlyPriceId: sandbox ? sandboxYearly.value() : liveYearly.value(),
  };
}
