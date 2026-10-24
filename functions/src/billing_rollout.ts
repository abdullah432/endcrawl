export type BillingRollout = { mode: string; pilotUid: string };

/** Every external entry point and retrying worker checks this before writes. */
export function billingEnabled(uid: string, rollout: BillingRollout): boolean {
  return uid.length > 0 && (rollout.mode === 'all' ||
    (rollout.mode === 'pilot' && rollout.pilotUid.length > 0 && uid === rollout.pilotUid));
}
