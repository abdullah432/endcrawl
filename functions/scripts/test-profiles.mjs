import { spawn } from 'node:child_process';
import { existsSync, writeFileSync, unlinkSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const localFiles = ['.env.local', '.secret.local'].map(name => resolve(root, 'functions', name));
if (localFiles.some(existsSync)) throw new Error('Move existing functions/.env.local and .secret.local aside first; refusing to overwrite them.');
const createdFiles = [];
const snapshotPath = process.env.PROFILE_TEST_SNAPSHOT ? resolve(process.env.PROFILE_TEST_SNAPSHOT) : '';
let pilotUid = 'local-profile-pilot';
if (snapshotPath) {
  const snapshot = JSON.parse(readFileSync(snapshotPath, 'utf8'));
  if (snapshot.projectId !== 'endcrawl-620c2' || snapshot.identity?.email !== 'abdullah234ktk@gmail.com' ||
      !/^[A-Za-z0-9_-]+$/.test(snapshot.identity?.uid ?? '')) {
    throw new Error('Snapshot must belong to the designated pilot account.');
  }
  pilotUid = snapshot.identity.uid;
}
function run(command, args, env = process.env) {
  return new Promise((resolveRun, reject) => {
    const child = spawn(command, args, { cwd: root, stdio: 'inherit', env });
    child.on('error', reject);
    child.on('exit', code => code === 0 ? resolveRun() : reject(new Error(`${command} exited ${code}`)));
  });
}
try {
  await run('npm', ['--prefix', 'functions', 'run', 'build']);
  writeFileSync(localFiles[0], `PROFILE_ROLLOUT_MODE=pilot\nPROFILE_PILOT_UID=${pilotUid}\n`, { flag: 'wx', mode: 0o600 });
  createdFiles.push(localFiles[0]);
  writeFileSync(localFiles[1], 'REVENUECAT_API_KEY=emulator-unused\nREVENUECAT_WEBHOOK_AUTH=Bearer billing-emulator-only\n', { flag: 'wx', mode: 0o600 });
  createdFiles.push(localFiles[1]);
  await run('firebase', ['emulators:exec', '--config', 'firebase.profiles-test.json',
    '--project', 'demo-lastreel-profiles', '--only', 'auth,firestore,functions',
    ...(process.env.PROFILE_TEST_DEBUG === 'true' ? ['--debug'] : []),
    'node --test --test-concurrency=1 functions/test/*.test.js functions/test/profiles.emulator.js'], {
    ...process.env, FUNCTIONS_EMULATOR_HOST: '127.0.0.1:15001',
    GCLOUD_PROJECT: 'demo-lastreel-profiles',
    PROFILE_TEST_UID: pilotUid, PROFILE_TEST_SNAPSHOT: snapshotPath,
  });
} finally {
  for (const file of createdFiles) if (existsSync(file)) unlinkSync(file);
}
