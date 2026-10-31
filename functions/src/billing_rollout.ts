export type BillingRollout = { mode: string; pilotUid: string; pilotUids?: string };

/** Every external entry point and retrying worker checks this before writes. */
export function billingEnabled(uid: string, rollout: BillingRollout): boolean {
  return uid.length > 0 && (rollout.mode === 'all' ||
    (rollout.mode === 'pilot' && (uid === rollout.pilotUid ||
      (rollout.pilotUids ?? '').split(',').some(candidate => candidate.trim() === uid && candidate.trim().length > 0))));
}
