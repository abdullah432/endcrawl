// Package only billing handlers; never deploy or resolve unrelated profile code.
import { mkdir, readFile, writeFile, copyFile, symlink, readdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const source = resolve(root, 'functions');
const output = resolve(root, 'output/billing-pilot/deployment');
const target = resolve(output, 'functions');
const snapshotsRoot = resolve(root, 'output/profile-pilot');
const snapshots = (await readdir(snapshotsRoot)).filter(name => /^\d{4}-\d{2}-\d{2}T/.test(name)).sort();
const snapshot = JSON.parse(await readFile(resolve(snapshotsRoot, snapshots.at(-1) ?? 'missing', 'snapshot.json'), 'utf8'));
const env = await readFile(resolve(source, '.env.endcrawl-620c2'), 'utf8');
const mode = /^BILLING_ROLLOUT_MODE=(.*)$/m.exec(env)?.[1]?.trim();
const uid = /^BILLING_PILOT_UID=(.*)$/m.exec(env)?.[1]?.trim();
if (mode !== 'pilot' || snapshot.projectId !== 'endcrawl-620c2' ||
    snapshot.identity?.email !== 'abdullah234ktk@gmail.com' || uid !== snapshot.identity?.uid) {
  throw new Error('Billing packaging requires pilot mode and the resolved designated account UID.');
}
await mkdir(resolve(target, 'lib'), { recursive: true, mode: 0o700 });
const original = JSON.parse(await readFile(resolve(source, 'package.json'), 'utf8'));
await writeFile(resolve(target, 'package.json'), JSON.stringify({
  name: 'lastreel-billing-pilot', private: true, type: 'module', main: 'lib/billing_functions.js',
  engines: original.engines, dependencies: original.dependencies,
}, null, 2));
for (const name of ['firebase.js', 'billing_rollout.js', 'billing_functions.js', 'reconcile.js', 'entitlements.js']) {
  await copyFile(resolve(source, 'lib', name), resolve(target, 'lib', name));
}
try { await symlink(resolve(source, 'node_modules'), resolve(target, 'node_modules'), 'dir'); }
catch (error) { if (error.code !== 'EEXIST') throw error; }
await writeFile(resolve(target, '.env.endcrawl-620c2'), `BILLING_ROLLOUT_MODE=pilot\nBILLING_PILOT_UID=${uid}\n`, { mode: 0o600 });
await writeFile(resolve(target, '.firebaseignore'), 'node_modules/\n');
await writeFile(resolve(output, 'firebase.json'), JSON.stringify({
  functions: { source: 'functions', runtime: 'nodejs22', codebase: 'default' },
}, null, 2));
console.log(`Prepared billing-only pilot deployment package: ${output}`);
