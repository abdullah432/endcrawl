export type WebBillingMode = 'off' | 'sandbox' | 'live';
export type WebPeriod = 'monthly' | 'yearly';
export type WebBillingConfig = {
  mode: WebBillingMode; purchaseLink: string; monthlyPriceId: string; yearlyPriceId: string;
};

export function sandboxAllowed(uid: string, uids: string): boolean {
  return uid.length > 0 && uids.split(',').some(value => value.trim() === uid);
}

export function checkoutUrl(config: WebBillingConfig, uid: string, period: unknown): string {
  if (config.mode === 'off' || !uid || uid.includes('/') ||
      (period !== 'monthly' && period !== 'yearly')) throw new Error('Checkout unavailable');
  const url = new URL(config.purchaseLink);
  if (url.protocol !== 'https:' || url.hostname !== 'pay.rev.cat' || url.port || url.username || url.password ||
      !/^\/[A-Za-z0-9_-]+\/?$/.test(url.pathname) || url.search || url.hash) throw new Error('Invalid purchase link');
  url.pathname = `${url.pathname.replace(/\/$/, '')}/${encodeURIComponent(uid)}`;
  url.searchParams.set('package_id', period === 'monthly' ? '$rc_monthly' : '$rc_annual');
  return url.toString();
}

/** Portal sessions are returned on demand, never persisted in the entitlement ledger. */
export function managementUrl(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.port && !url.username && !url.password &&
      ['apps.apple.com', 'play.google.com', 'customer-portal.paddle.com', 'sandbox-customer-portal.paddle.com'].includes(url.hostname)
      ? url.toString() : null;
  } catch { return null; }
}

/** Follow the store that granted verified Pro, including paid-store fallbacks. */
export function managementUrlForStore(value: unknown, store: string | null): string | null {
  const raw = managementUrl(value);
  if (store === 'paddle') return raw && ['customer-portal.paddle.com', 'sandbox-customer-portal.paddle.com'].includes(new URL(raw).hostname) ? raw : null;
  const fallback = store === 'play_store' ? 'https://play.google.com/store/account/subscriptions'
    : ['app_store', 'mac_app_store'].includes(store ?? '') ? 'https://apps.apple.com/account/subscriptions' : null;
  return fallback && raw && new URL(raw).hostname === new URL(fallback).hostname ? raw : fallback;
}

export function priceOffer(price: Record<string, any>, id: string, period: WebPeriod) {
  const cycle = period === 'monthly' ? 'month' : 'year';
  const amount = price.unit_price?.amount;
  const currency = price.unit_price?.currency_code;
  if (price.id !== id || price.status !== 'active' || price.billing_cycle?.interval !== cycle ||
      price.billing_cycle?.frequency !== 1 || price.trial_period != null ||
      typeof amount !== 'string' || !/^\d+$/.test(amount) || Number(amount) <= 0 ||
      !Number.isSafeInteger(Number(amount)) || typeof currency !== 'string' || !/^[A-Z]{3}$/.test(currency)) {
    throw new Error('Invalid subscription price');
  }
  const formatter = new Intl.NumberFormat('en-US', { style: 'currency', currency, currencyDisplay: 'code' });
  const digits = formatter.resolvedOptions().maximumFractionDigits ?? 2;
  return { period, packageId: period === 'monthly' ? '$rc_monthly' : '$rc_annual',
    price: formatter.format(Number(amount) / 10 ** digits),
    pricePerMonth: period === 'yearly' ? formatter.format(Number(amount) / 10 ** digits / 12) : null,
    amountMinor: Number(amount), currency,
    detail: period === 'monthly' ? 'Billed every month' : 'Billed once a year' };
}
