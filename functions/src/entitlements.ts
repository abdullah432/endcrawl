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

export function shouldReplace(current: RecordValue | undefined, next: BillingEntitlement): boolean {
  return !current || next.sourceUpdatedAtMs >= (current.sourceUpdatedAtMs ?? 0);
}
