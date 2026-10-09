const now = Date.parse('2026-10-09T00:00:00Z');
export function customer(expiry = now + 86400000, subscription = {}) {
  return {request_date_ms: now, subscriber: {management_url: 'https://play.google.com/store/account/subscriptions',
    entitlements: {pro: {product_identifier: 'lastreel:monthly', expires_date: expiry == null ? null : new Date(expiry).toISOString()}},
    subscriptions: {'lastreel:monthly': { ...subscription}}}};
}
