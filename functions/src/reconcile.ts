import type { Firestore } from 'firebase-admin/firestore';
import { normalizeEntitlement, shouldReplace } from './entitlements.js';

/** The callable and webhook worker use the same canonical reconciliation. */
export async function reconcileEntitlement(uid: string, db: Firestore,
  loadCustomer: (uid: string) => Promise<Record<string, any>>, now = Date.now()) {
  const customer = await loadCustomer(uid);
  if (!customer.subscriber || typeof customer.subscriber !== 'object') throw new Error('Invalid customer information');
  const next = normalizeEntitlement(customer, now);
  const ref = db.doc(`billingEntitlements/${uid}`);
  return db.runTransaction(async (transaction) => {
    const current = (await transaction.get(ref)).data();
    if (!shouldReplace(current, next)) return current!;
    if (next.plan === 'free' && (current?.plan === 'pro' || current?.lapsed)) next.lapsed = true;
    transaction.set(ref, next);
    return next;
  });
}
