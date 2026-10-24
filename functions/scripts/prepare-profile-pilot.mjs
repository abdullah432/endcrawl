// Read-only production preparation: one Auth lookup and that UID's profile and
// projects. No remote writes, deployment, or token/password export.
import { applicationDefault } from 'firebase-admin/app';
import { execFileSync } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { realpathSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const projectId = 'endcrawl-620c2';
const email = 'abdullah234ktk@gmail.com';
if (process.env.FIREBASE_AUTH_EMULATOR_HOST || process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Run pilot preparation outside the emulator environment.');
}
async function prepare() {
  let getToken;
  try {
    // Reuse the logged-in Firebase CLI session without displaying credentials.
    const cli = realpathSync(execFileSync('which', ['firebase'], {
      encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
    }).trim());
    const require = createRequire(cli);
    const cliAuth = require('../auth.js');
    const account = cliAuth.getGlobalDefaultAccount();
    if (!account?.tokens?.refresh_token) throw new Error('No Firebase CLI login.');
    getToken = async () => {
      const token = await cliAuth.getAccessToken(account.tokens.refresh_token, ['https://www.googleapis.com/auth/cloud-platform']);
      return { access_token: token.access_token, expires_in: 3600 };
    };
  } catch {
    const credential = applicationDefault();
    getToken = () => credential.getAccessToken();
  }
  const { access_token: token } = await getToken();
  async function read(url, optional = false, body) {
    const response = await fetch(url, {
      method: body ? 'POST' : 'GET',
      headers: { Authorization: `Bearer ${token}`, 'x-goog-user-project': projectId, 'Content-Type': 'application/json' },
      ...(body ? { body: JSON.stringify(body) } : {}), signal: AbortSignal.timeout(30_000),
    });
    if (optional && response.status === 404) return null;
    if (!response.ok) throw new Error(`Read-only pilot snapshot failed: HTTP ${response.status}`);
    return response.json();
  }
  const result = await read(`https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:lookup`, false, { email: [email] });
  const user = result.users?.find(user => user.email?.toLowerCase() === email);
  if (!user?.localId) throw new Error('Pilot account was not found.');
  const uid = user.localId;
  const base = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${encodeURIComponent(uid)}`;
  const profile = await read(base, true);
  const projects = [];
  let pageToken = '';
  do {
    const page = await read(`${base}/projects?pageSize=100${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`);
    projects.push(...(page.documents ?? []));
    pageToken = page.nextPageToken ?? '';
  } while (pageToken);
  const output = resolve(root, 'output/profile-pilot', new Date().toISOString().replaceAll(':', '-'));
  await mkdir(output, { recursive: true, mode: 0o700 });
  const snapshot = { capturedAt: new Date().toISOString(), projectId,
    identity: { uid, name: user.displayName ?? null, email: user.email ?? null,
      providers: (user.providerUserInfo ?? []).map(provider => provider.providerId) }, profile, projects };
  await writeFile(resolve(output, 'snapshot.json'), JSON.stringify(snapshot, null, 2), { mode: 0o600, flag: 'wx' });
  await writeFile(resolve(output, 'pilot.env'), `PROFILE_ROLLOUT_MODE=pilot\nPROFILE_PILOT_UID=${uid}\n`, { mode: 0o600, flag: 'wx' });
  await writeFile(resolve(output, 'app-pilot-defines.json'), JSON.stringify({
    PROFILE_SYNC_ENABLED: 'true', PROFILE_SYNC_PILOT_UID: uid,
    FIREBASE_AUTH_DOMAIN: `${projectId}.web.app`,
  }, null, 2), { mode: 0o600, flag: 'wx' });
  console.log(`Read-only pilot prepared: UID ${uid}, ${projects.length} projects, parent ${profile ? 'exists' : 'missing'}.`);
  console.log(`Private snapshot and unapplied pilot settings: ${output}`);
  console.log('No production data, rollout settings, or deployments were changed.');
}
// SDK/network error objects can contain authorization headers. Never dump them.
await prepare().catch(() => {
  console.error('Read-only pilot preparation failed. Check Firebase login, project permissions, and network access. No deployment was performed.');
  process.exitCode = 1;
});
