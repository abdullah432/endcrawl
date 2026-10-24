import { FieldValue, Firestore, Timestamp } from 'firebase-admin/firestore';

export type ProfileRollout = { mode: string; pilotUid: string };
export function profileEnabled(uid: string, rollout: ProfileRollout): boolean {
  return rollout.mode === 'all' ||
    (rollout.mode === 'pilot' && rollout.pilotUid.length > 0 && uid === rollout.pilotUid);
}

export const defaultPreferences = {
  defaultFps: 24, defaultFormatId: '16x9', safeGuides: true,
  readabilityWarnings: true, haptics: true, renderNotifications: true,
  crashReports: true, usageAnalytics: true, personalisedAds: false,
};

type Identity = { displayName?: string | null; email?: string | null };
type IdentityReader = (uid: string) => Promise<Identity>;
const metadataKeys = ['name', 'email', 'projectCount'];
const textOrNull = (value: unknown) => typeof value === 'string' && value.trim() ? value.trim() : null;

export function hasProfileMetadata(data: Record<string, unknown>): boolean {
  return metadataKeys.every(key => Object.hasOwn(data, key)) &&
    (data.name === null || typeof data.name === 'string') &&
    (data.email === null || typeof data.email === 'string') &&
    Number.isInteger(data.projectCount) && (data.projectCount as number) >= 0;
}

/** Recount current state rather than applying event deltas. All reads precede writes.
 * A projected query also counts documents that an older app cannot deserialize.
 */
export async function reconcileProfile(
  uid: string, db: Firestore, readIdentity: IdentityReader, create = false,
): Promise<'synced' | 'missing' | 'suspended'> {
  const profile = db.doc(`users/${uid}`);
  const state = db.doc(`profileSyncState/${uid}`);
  return db.runTransaction(async tx => {
    const [snapshot, suspension] = await tx.getAll(profile, state);
    const until = suspension.get('suspendedUntil');
    if (until instanceof Timestamp && until.toMillis() > Date.now()) return 'suspended';
    if (!snapshot.exists && !create) return 'missing';
    const projects = await tx.get(profile.collection('projects').select());
    // Inside the retryable transaction so a retry does not reuse an old identity.
    const identity = await readIdentity(uid);
    const existing = snapshot.data() ?? {};
    const next = {
      name: textOrNull(identity.displayName) ?? textOrNull(existing.name),
      email: textOrNull(identity.email) ?? textOrNull(existing.email),
      projectCount: projects.size,
    };
    const patch: Record<string, unknown> = {};
    for (const key of metadataKeys as (keyof typeof next)[]) {
      if (!Object.hasOwn(existing, key) || existing[key] !== next[key]) patch[key] = next[key];
    }
    if (!Object.hasOwn(existing, 'schemaVersion')) patch.schemaVersion = 1;
    if (!Object.hasOwn(existing, 'marketingOptIn')) patch.marketingOptIn = false;
    if (!Object.hasOwn(existing, 'preferences')) patch.preferences = defaultPreferences;
    if (Object.keys(patch).length) {
      tx.set(profile, { ...patch, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    }
    return 'synced';
  });
}

/** A server guard also protects against requests already in flight on another device.
 * Expiration lets an interrupted deletion recover on a later session.
 */
export async function setProfileSuspended(uid: string, db: Firestore, suspended: boolean) {
  const state = db.doc(`profileSyncState/${uid}`);
  if (suspended) {
    await state.set({ suspendedUntil: Timestamp.fromMillis(Date.now() + 10 * 60_000) });
  } else {
    await state.delete();
  }
}
