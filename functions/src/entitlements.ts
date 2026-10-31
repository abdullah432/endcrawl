export type BillingEntitlement = {
  schemaVersion: 1; plan: 'free' | 'pro'; period: 'monthly' | 'yearly' | null;
  expiresAtMs: number | null; trialEndsAtMs: number | null; willRenew: boolean;
  managementUrl: string | null; lapsed: boolean; verifiedAtMs: number; sourceUpdatedAtMs: number;
};
type RecordValue = Record<string, any>;
const time = (value: unknown): number | null => {
  if (typeof value !== 'string') return null;
  const result = Date.parse(value);
  return Number.isFinite(result) ? result : null;
};

/** Normalizes canonical customer information; events never grant access directly. */
export function normalizeEntitlement(body: RecordValue, now: number): BillingEntitlement {
  const subscriber = body.subscriber ?? {};
  const pro = subscriber.entitlements?.pro;
  const subscription = subscriber.subscriptions?.[pro?.product_identifier] ?? {};
  const expiry = time(pro?.expires_date);
  const grace = time(subscription.grace_period_expires_date);
  const effectiveExpiry = grace == null ? expiry : Math.max(expiry ?? 0, grace);
  const validExpiry = pro?.expires_date == null || expiry != null;
  const active = !!pro && validExpiry && (effectiveExpiry == null || effectiveExpiry > now);
  const product = subscription.product_plan_identifier ?? pro?.product_identifier?.split(':').at(-1);
  const period = ['monthly', 'lastreel_pro_monthly'].includes(product) ? 'monthly'
    : ['yearly', 'annual', 'lastreel_pro_yearly'].includes(product) ? 'yearly' : null;
  const url = subscriber.management_url ?? ({
    play_store: 'https://play.google.com/store/account/subscriptions',
    app_store: 'https://apps.apple.com/account/subscriptions',
    mac_app_store: 'https://apps.apple.com/account/subscriptions',
  } as Record<string, string>)[subscription.store];
  return {
    schemaVersion: 1, plan: active ? 'pro' : 'free', period: active ? period : null,
    expiresAtMs: active ? effectiveExpiry : null,
    trialEndsAtMs: active && subscription.period_type === 'trial' ? effectiveExpiry : null,
    willRenew: active && !subscription.unsubscribe_detected_at,
    managementUrl: typeof url === 'string' && /^https:\/\/(apps\.apple\.com|play\.google\.com)\//.test(url) ? url : null,
    lapsed: !!pro && !active, verifiedAtMs: now,
    sourceUpdatedAtMs: typeof body.request_date_ms === 'number' ? body.request_date_ms : now,
  };
}

export function affectedAccounts(event: RecordValue): string[] {
  return [...new Set([event.app_user_id, event.original_app_user_id, ...(event.aliases ?? []),
    ...(event.transferred_from ?? []), ...(event.transferred_to ?? [])]
    .filter((id): id is string => typeof id === 'string' && id.length > 0 && !id.startsWith('$RCAnonymousID:') && !id.includes('/')))];
}

/** A provider-specific, server-owned record for the Firebase console. */
export function subscriptionSnapshot(uid: string, body: RecordValue, entitlement: BillingEntitlement, now: number) {
  const subscriptions = body.subscriber?.subscriptions;
  const entries = subscriptions && typeof subscriptions === 'object' && !Array.isArray(subscriptions)
    ? Object.entries(subscriptions).filter((entry): entry is [string, RecordValue] =>
      !!entry[1] && typeof entry[1] === 'object' && !Array.isArray(entry[1])) : [];
  const entitledProduct = body.subscriber?.entitlements?.pro?.product_identifier;
  const selected = entries.find(([product]) => product === entitledProduct) ??
    entries.sort((a, b) => (time(b[1].expires_date) ?? 0) - (time(a[1].expires_date) ?? 0))[0];
  const [productId, subscription] = selected ?? [null, null];
  const periodEnd = time(subscription?.expires_date);
  const graceEnd = time(subscription?.grace_period_expires_date);
  const status = entitlement.plan === 'pro'
    ? subscription?.period_type === 'trial' ? 'trialing'
      : graceEnd != null && (periodEnd == null || graceEnd > periodEnd) && graceEnd > now ? 'grace'
        : 'active'
    : subscription?.refunded_at ? 'refunded'
      : subscription ? periodEnd != null && periodEnd <= now ? 'expired' : 'inactive'
        : 'none';
  return {
    schemaVersion: 1, uid, provider: 'revenuecat', status,
    currentPeriodEnd: periodEnd == null ? null : new Date(periodEnd),
    subKey: productId == null ? null : `revenuecat:${productId}`,
    productId, store: typeof subscription?.store === 'string' ? subscription.store : null,
    isSandbox: typeof subscription?.is_sandbox === 'boolean' ? subscription.is_sandbox : null,
    updatedAt: new Date(now), sourceUpdatedAtMs: entitlement.sourceUpdatedAtMs,
  };
}

export function shouldReplace(current: RecordValue | undefined, next: BillingEntitlement): boolean {
  return !current || next.sourceUpdatedAtMs >= (current.sourceUpdatedAtMs ?? 0);
}
